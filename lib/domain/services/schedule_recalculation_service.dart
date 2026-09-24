import '../entities/day_schedule.dart';
import '../entities/facility.dart';
import '../entities/live_operating_status.dart';
import '../entities/plan_preference.dart';
import '../entities/schedule_change.dart';
import '../entities/schedule_item.dart';
import '../entities/schedule_recalculation_request.dart';
import '../entities/schedule_recalculation_result.dart';
import '../entities/today_access_result.dart';
import '../entities/replanning_context.dart';
import '../enums/facility_category.dart';
import '../enums/fixed_time_status.dart';
import '../enums/schedule_change_type.dart';
import '../enums/schedule_item_type.dart';
import '../enums/today_access_kind.dart';
import 'schedule_engine.dart';
import 'realtime_replanning_service.dart';

class ScheduleRecalculationService {
  const ScheduleRecalculationService({
    this.scheduleEngine = const ScheduleEngine(),
    this.replanningService = const RealtimeReplanningService(),
  });

  final ScheduleEngine scheduleEngine;
  final RealtimeReplanningService replanningService;

  ScheduleRecalculationResult createProposal(
    ScheduleRecalculationRequest request, {
    Map<String, int> simulatedWaitMinutesByFacilityId = const <String, int>{},
  }) {
    final nowMinutes = request.now.hour * 60 + request.now.minute;
    final preferenceById = {
      for (final preference in request.preferences)
        preference.facilityId: preference,
    };

    final facilityById = {
      for (final facility in request.facilities) facility.id: facility,
    };
    final successfulTodayResultByFacility = <String, TodayAccessResult>{};
    for (final result in request.todayAccessResults) {
      if (!result.fixesTime) continue;
      final previous = successfulTodayResultByFacility[result.facilityId];
      if (previous == null || result.updatedAt.isAfter(previous.updatedAt)) {
        successfulTodayResultByFacility[result.facilityId] = result;
      }
    }
    final alignedCurrentItems = request.currentSchedule.items
        .map((item) => _alignConfirmedItem(
              item: item,
              facility: item.facilityId == null ? null : facilityById[item.facilityId],
              preference: item.facilityId == null ? null : preferenceById[item.facilityId],
              todayResult: item.facilityId == null
                  ? null
                  : successfulTodayResultByFacility[item.facilityId],
            ))
        .toList(growable: false);

    final executionByItemId = {
      for (final record in request.todayExecutionRecords)
        record.scheduleItemId: record,
    };
    final executedOriginalStarts = alignedCurrentItems
        .where((item) => executionByItemId.containsKey(item.id))
        .map(_start)
        .toList(growable: false);
    final latestExecutedOriginalStart = executedOriginalStarts.isEmpty
        ? null
        : executedOriginalStarts.reduce((a, b) => a > b ? a : b);

    final warnings = <String>[];
    final preserved = alignedCurrentItems
        .where((item) {
          final start = _start(item);
          final end = _end(item);
          if (item.type == ScheduleItemType.entry ||
              item.type == ScheduleItemType.exit) {
            return true;
          }

          // An explicitly completed/skipped occurrence is removed from the
          // remaining plan. Its execution record remains the source of truth.
          if (executionByItemId.containsKey(item.id)) {
            return false;
          }

          final facilityId = item.facilityId;
          final facility =
              facilityId == null ? null : facilityById[facilityId];
          final preference =
              facilityId == null ? null : preferenceById[facilityId];

          // An acquired/confirmed Today access result is authoritative even
          // after its clock time has passed. If the source schedule contains
          // an impossible overlap with a flexible meal, release that meal
          // before applying the legacy "elapsed actions are facts" rule.
          // This keeps actual-completion replanning on the same conflict
          // resolution path as the normal Today acquired-DPA flow.
          final isFlexibleMeal =
              item.type == ScheduleItemType.breakfast ||
              item.type == ScheduleItemType.lunch ||
              item.type == ScheduleItemType.dinner;
          if (isFlexibleMeal &&
              preference?.fixedTimeStatus != FixedTimeStatus.confirmed &&
              _conflictsWithAuthoritativeTodayAccess(
                item: item,
                alignedItems: alignedCurrentItems,
                confirmedTodayResultByFacility:
                    successfulTodayResultByFacility,
              )) {
            warnings.add(
              '${item.title}は取得済みの固定アクセス時刻と重なるため、固定アクセスを優先して再配置します。',
            );
            return false;
          }

          // Without execution records, keep the legacy rule: elapsed actions
          // are facts. Once an actual occurrence is recorded, elapsed slots
          // scheduled after that occurrence are not assumed to have happened;
          // they are released for replanning from the actual recorded time.
          if (end <= nowMinutes) {
            if (latestExecutedOriginalStart != null &&
                start > latestExecutedOriginalStart) {
              return false;
            }
            return true;
          }

          final unavailable = facilityId != null &&
              _isUnavailable(request.operatingStatuses[facilityId]);

          // An acquired/confirmed Today access result is authoritative. Keep
          // that exact item as an anchor even when its pre-trip preference was
          // not fixed. Flexible items are moved around this anchor below.
          if (facilityId != null &&
              successfulTodayResultByFacility.containsKey(facilityId)) {
            return true;
          }

          // A currently running activity is normally protected, but a facility
          // that has just gone down must be released so the remaining plan can
          // recover from the disruption.
          if (start <= nowMinutes && nowMinutes < end) {
            if (item.type == ScheduleItemType.breakTime) {
              return false;
            }
            if (latestExecutedOriginalStart != null &&
                start > latestExecutedOriginalStart) {
              return false;
            }
            return !unavailable;
          }

          if (unavailable) {
            return false;
          }

          return _isProtectedFutureItem(
            item: item,
            facility: facility,
            preference: preference,
            released: facilityId != null &&
                request.releasedFacilityIds.contains(facilityId),
          );
        })
        .toList(growable: true);

    final requestedBreakMinutes = request.breakDurationMinutes;
    if (requestedBreakMinutes != null && requestedBreakMinutes > 0) {
      var breakStart = nowMinutes;
      for (final item in preserved) {
        final start = _start(item);
        final end = _end(item);
        if (start <= nowMinutes && nowMinutes < end &&
            item.type != ScheduleItemType.entry &&
            item.type != ScheduleItemType.exit) {
          breakStart = end > breakStart ? end : breakStart;
        }
      }
      final breakEnd = breakStart + requestedBreakMinutes;
      final exitMinutes =
          request.settings.exitTimeHour * 60 + request.settings.exitTimeMinute;
      if (breakEnd <= exitMinutes) {
        preserved.add(
          ScheduleItem(
            id: 'today_break_${request.now.millisecondsSinceEpoch}',
            title: 'ひと休み',
            type: ScheduleItemType.breakTime,
            startHour: breakStart ~/ 60,
            startMinute: breakStart % 60,
            endHour: breakEnd ~/ 60,
            endMinute: breakEnd % 60,
            reason: '当日に追加した休憩',
            note: '$requestedBreakMinutes分休憩',
          ),
        );
        if (breakStart > nowMinutes) {
          warnings.add(
            '進行中の予定を優先し、休憩開始を'
            '${(breakStart ~/ 60).toString().padLeft(2, '0')}:'
            '${(breakStart % 60).toString().padLeft(2, '0')}へ調整しました。',
          );
        }
      } else {
        warnings.add('指定した休憩は退園希望時刻を超えるため追加できませんでした。');
      }
    }

    final preservedFacilityIds = preserved
        .map((item) => item.facilityId)
        .whereType<String>()
        .toSet();
    _appendConfirmedAccessConflictWarnings(
      alignedItems: alignedCurrentItems,
      confirmedTodayResultByFacility: successfulTodayResultByFacility,
      preferenceById: preferenceById,
      warnings: warnings,
    );

    final eligibleFacilities = request.facilities
        .where((facility) {
          if (request.executedFacilityIds.contains(facility.id)) {
            warnings.add('${facility.name}は当日の実績で完了・スキップ済みのため再配置しません。');
            return false;
          }
          if (preservedFacilityIds.contains(facility.id)) {
            return false;
          }
          final liveStatus = request.operatingStatuses[facility.id];
          if (liveStatus != null &&
              liveStatus.state != LiveOperatingState.operating &&
              liveStatus.state != LiveOperatingState.unknown) {
            warnings.add(
              '${facility.name}は${liveStatus.state.label}のため再配置対象から除外しました。',
            );
            return false;
          }
          final targetDate = request.settings.visitDate ?? request.now;
          if (!facility.canAddToPlanAt(targetDate)) {
            warnings.add('${facility.name}は営業対象外のため再配置対象から除外しました。');
            return false;
          }
          final preference = preferenceById[facility.id];
          final liveWait = request.waitTimes[facility.id];
          final simulatedWait = simulatedWaitMinutesByFacilityId[facility.id];
          final conditionalWaitMinutes = simulatedWait ??
              ((liveWait != null && !liveWait.isStaleAt(request.now))
                  ? liveWait.waitMinutes
                  : null);
          // Today uses the same conditional-wish meaning as PRE-TRIP. A fresh
          // actual (or DEBUG simulated) wait above the user's limit removes a
          // normal/optional wish from this replan. High/highest wishes remain
          // candidates and are reported instead of silently disappearing.
          if (preference != null &&
              conditionalWaitMinutes != null &&
              !preference.waitTolerance.allows(conditionalWaitMinutes)) {
            final protectedPriority = preference.priority.name == 'high' ||
                preference.priority.name == 'highest';
            if (!protectedPriority) {
              warnings.add(
                '${facility.name}は現在の待ち時間$conditionalWaitMinutes分が条件'
                '（${preference.waitTolerance.label}）を超えたため、今回は見送ります。',
              );
              return false;
            }
            warnings.add(
              '${facility.name}は現在の待ち時間$conditionalWaitMinutes分が条件を超えていますが、'
              '優先度が高いため候補に残します。',
            );
          }
          return true;
        })
        .toList(growable: false);

    final eligibleIds = eligibleFacilities
        .map((facility) => facility.id)
        .toSet();
    final eligiblePreferences = request.preferences
        .where((preference) => eligibleIds.contains(preference.facilityId))
        .toList(growable: false);

    _appendLiveWaitDecisionWarnings(
      request: request,
      eligibleFacilities: eligibleFacilities,
      warnings: warnings,
      simulatedWaitMinutesByFacilityId: simulatedWaitMinutesByFacilityId,
    );

    final explicitCurrentFacility =
        _facilityById(request.facilities, request.currentFacilityId);
    final currentFacility = explicitCurrentFacility ?? _latestFacility(
      preserved: preserved,
      facilities: request.facilities,
    );
    if (explicitCurrentFacility != null) {
      warnings.add('現在地: ${explicitCurrentFacility.name} を起点に再計画します。');
    }
    final nextFixed = _nextProtectedFuture(
      request: request,
      items: alignedCurrentItems,
      nowMinutes: nowMinutes,
    );
    final nextDestination = nextFixed == null
        ? null
        : _facilityById(request.facilities, nextFixed.facilityId);

    final replanningContext = ReplanningContext(
      now: request.now,
      facilities: eligibleFacilities,
      preferences: eligiblePreferences,
      nextFixedStartMinutes: nextFixed == null ? null : _start(nextFixed),
      currentFacility: currentFacility,
      nextDestination: nextDestination,
      weather: request.weather,
      passStatuses: request.passStatuses,
      fatigueLevel: request.fatigueLevel,
      hasBaggage: request.hasBaggage,
      hotelBreakAvailable: request.hotelBreakAvailable,
    );

    final replanningSuggestions = replanningService.assess(replanningContext);
    for (final suggestion in replanningSuggestions) {
      warnings.add('再計画候補: ${suggestion.title} - ${suggestion.reason}');
    }

    final prioritizedFacilities = replanningService.prioritizeForCurrentWeather(
      replanningContext,
    );

    final replanningSettings = request.settings.copyWith(
      queueArrivalTimeHour: request.now.hour,
      queueArrivalTimeMinute: request.now.minute,
      // Existing meal blocks are protected anchors during live replanning.
      // Do not create a second breakfast/lunch/dinner from the morning planner.
      wantsBreakfast: false,
      wantsLunch: false,
      wantsDinner: false,
    );

    final generated = scheduleEngine.generate(
      settings: replanningSettings,
      facilities: prioritizedFacilities,
      preferences: eligiblePreferences,
      waitProfiles: request.waitProfiles,
    );

    final preservedKeys = preserved.map(_key).toSet();
    final anchors = preserved
        .where(
          (item) =>
              item.type != ScheduleItemType.entry &&
              item.type != ScheduleItemType.exit &&
              _end(item) > nowMinutes,
        )
        .toList(growable: false)
      ..sort((left, right) => _start(left).compareTo(_start(right)));

    final exitMinutes =
        request.settings.exitTimeHour * 60 + request.settings.exitTimeMinute;
    final generatedCandidates = generated.items
        .where(
          (item) =>
              item.type != ScheduleItemType.entry &&
              item.type != ScheduleItemType.exit &&
              item.type != ScheduleItemType.breakTime &&
              _start(item) >= nowMinutes &&
              !preservedKeys.contains(_key(item)),
        )
        .toList(growable: false)
      ..sort((left, right) => _start(left).compareTo(_start(right)));

    final futureGenerated = <ScheduleItem>[];
    var cursor = nowMinutes;
    for (final item in generatedCandidates) {
      var duration = _end(item) - _start(item);
      if (duration <= 0) continue;

      int? liveWaitMinutes;
      String? liveWaitSourceLabel;
      final facilityId = item.facilityId;
      final liveWait =
          facilityId == null ? null : request.waitTimes[facilityId];
      final simulatedWait = facilityId == null
          ? null
          : simulatedWaitMinutesByFacilityId[facilityId];
      final plannedWait = item.estimatedWaitMinutes;
      final usableLiveWait = liveWait != null && !liveWait.isStaleAt(request.now);
      final effectiveWait = simulatedWait ?? (usableLiveWait ? liveWait.waitMinutes : null);
      if (effectiveWait != null &&
          plannedWait != null &&
          !_usesPriorityAccessPlanning(item)) {
        liveWaitMinutes = effectiveWait;
        liveWaitSourceLabel = simulatedWait != null
            ? 'シミュレーション待ち時間'
            : liveWait!.source.label;
        final experienceMinutes =
            item.experienceMinutes ?? (duration - plannedWait).clamp(0, 999).toInt();
        duration = effectiveWait + experienceMinutes;
        final delta = effectiveWait - plannedWait;
        if (delta.abs() >= 15) {
          warnings.add(
            '${item.title}の待ち時間を計画$plannedWait分から'
            '${simulatedWait != null ? 'シミュレーション' : '当日'}'
            '$effectiveWait分へ更新して再配置しました。',
          );
        }
      }

      var start = _start(item) > cursor ? _start(item) : cursor;
      var movedPastAnchor = true;
      while (movedPastAnchor) {
        movedPastAnchor = false;
        final end = start + duration;
        for (final anchor in anchors) {
          if (_rangesOverlap(start, end, _start(anchor), _end(anchor))) {
            start = _end(anchor);
            movedPastAnchor = true;
            break;
          }
        }
      }

      final end = start + duration;
      if (end > exitMinutes) {
        warnings.add(
          '${item.title}は現在の待ち時間・固定予定を反映すると退園時刻までに収まらないため、今回は見送り候補にしました。',
        );
        continue;
      }

      final shifted = _shiftScheduleItem(
        item,
        startMinutes: start,
        endMinutes: end,
        liveWaitMinutes: liveWaitMinutes,
        liveWaitSourceLabel: liveWaitSourceLabel,
      );
      futureGenerated.add(shifted);
      cursor = end;
    }

    final exitItem = alignedCurrentItems
        .where((item) => item.type == ScheduleItemType.exit)
        .cast<ScheduleItem?>()
        .firstOrNull;

    final merged = <ScheduleItem>[
      ...preserved.where((item) => item.type != ScheduleItemType.exit),
      ...futureGenerated,
      ?exitItem,
    ]..sort((a, b) => _start(a).compareTo(_start(b)));

    final after = DaySchedule(
      id: 'schedule_${DateTime.now().millisecondsSinceEpoch}',
      parkId: request.currentSchedule.parkId,
      items: List<ScheduleItem>.unmodifiable(merged),
      createdAt: DateTime.now(),
    );

    return ScheduleRecalculationResult(
      beforeSchedule: request.currentSchedule,
      afterSchedule: after,
      preservedItems: List<ScheduleItem>.unmodifiable(preserved),
      changes: List<ScheduleChange>.unmodifiable(
        _buildChanges(request.currentSchedule, after, preservedKeys),
      ),
      warnings: List<String>.unmodifiable(warnings),
      createdAt: DateTime.now(),
    );
  }


  ScheduleItem _alignConfirmedItem({
    required ScheduleItem item,
    required Facility? facility,
    required PlanPreference? preference,
    required TodayAccessResult? todayResult,
  }) {
    if (facility == null || preference == null) {
      return item;
    }
    final hasTodayResult = todayResult?.fixesTime == true;
    if (!hasTodayResult &&
        preference.fixedTimeStatus != FixedTimeStatus.confirmed) {
      return item;
    }
    final timeText = hasTodayResult
        ? todayResult!.time
        : facility.isRestaurant
            ? preference.reservationTime
            : (facility.category == FacilityCategory.show ||
                    facility.category == FacilityCategory.parade)
                ? preference.preferredPerformanceTime
                : preference.scheduledAccessTime;
    final start = _parseClockMinutes(timeText);
    if (start == null) return item;

    var duration = (_end(item) - _start(item)).clamp(1, 24 * 60).toInt();
    if (facility.isRestaurant) {
      duration = facility.totalPlannedDurationMinutes.clamp(1, 24 * 60).toInt();
    } else if (facility.category == FacilityCategory.show ||
        facility.category == FacilityCategory.parade) {
      duration = facility.durationMinutes.clamp(1, 24 * 60).toInt();
    } else if (preference.accessMethod.name != 'standby') {
      duration = (facility.durationMinutes +
              (item.priorityAccessBufferMinutes ?? 10))
          .clamp(1, 24 * 60)
          .toInt();
    }
    final adjustedStart = facility.isRestaurant
        ? start - facility.outboundTravelMinutes
        : start;
    final end = adjustedStart + duration;
    return ScheduleItem(
      id: item.id,
      title: item.title,
      type: item.type,
      startHour: adjustedStart ~/ 60,
      startMinute: adjustedStart % 60,
      endHour: end ~/ 60,
      endMinute: end % 60,
      facilityId: item.facilityId,
      reason: hasTodayResult
          ? '当日に実際に取得・当選した${todayResult!.kind.label}の時刻を固定して再最適化します。'
          : _sanitizeLegacyReason(item.reason),
      note: item.note,
      estimatedWaitMinutes: item.estimatedWaitMinutes,
      experienceMinutes: item.experienceMinutes,
      waitEstimateSource: item.waitEstimateSource,
      accessMethod: preference.accessMethod,
      usesVacationPackageUnlimited: item.usesVacationPackageUnlimited,
      standbyWaitMinutes: item.standbyWaitMinutes,
      priorityAccessBufferMinutes: item.priorityAccessBufferMinutes,
    );
  }

  int? _parseClockMinutes(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    return hour * 60 + minute;
  }

  bool _conflictsWithAuthoritativeTodayAccess({
    required ScheduleItem item,
    required List<ScheduleItem> alignedItems,
    required Map<String, TodayAccessResult> confirmedTodayResultByFacility,
  }) {
    for (final fixed in alignedItems) {
      final facilityId = fixed.facilityId;
      if (facilityId == null || fixed.id == item.id) continue;
      if (!confirmedTodayResultByFacility.containsKey(facilityId)) continue;
      if (_rangesOverlap(
        _start(item),
        _end(item),
        _start(fixed),
        _end(fixed),
      )) {
        return true;
      }
    }
    return false;
  }

  void _appendConfirmedAccessConflictWarnings({
    required List<ScheduleItem> alignedItems,
    required Map<String, TodayAccessResult> confirmedTodayResultByFacility,
    required Map<String, PlanPreference> preferenceById,
    required List<String> warnings,
  }) {
    final fixedTodayItems = alignedItems
        .where((item) => item.facilityId != null &&
            confirmedTodayResultByFacility.containsKey(item.facilityId))
        .toList(growable: false);
    for (final acquired in fixedTodayItems) {
      for (final other in alignedItems) {
        if (identical(acquired, other) || acquired.id == other.id) continue;
        if (other.type == ScheduleItemType.entry ||
            other.type == ScheduleItemType.exit ||
            other.type == ScheduleItemType.breakTime) {
          continue;
        }
        final otherPreference = other.facilityId == null
            ? null
            : preferenceById[other.facilityId];
        final otherIsFlexibleMeal =
            other.type == ScheduleItemType.breakfast ||
            other.type == ScheduleItemType.lunch ||
            other.type == ScheduleItemType.dinner;
        if (otherIsFlexibleMeal &&
            otherPreference?.fixedTimeStatus != FixedTimeStatus.confirmed) {
          // Flexible meals are automatically released and replanned around
          // the authoritative Today access, so no manual-conflict warning is
          // needed for this pair.
          continue;
        }
        if (!_rangesOverlap(
          _start(acquired),
          _end(acquired),
          _start(other),
          _end(other),
        )) {
          continue;
        }
        final result = confirmedTodayResultByFacility[acquired.facilityId]!;
        warnings.add(
          '${acquired.title}の${result.kind.label}実績 ${result.time} は、'
          '${other.title}（${other.timeRangeLabel}）と競合します。取得実績の時刻は動かさず、どちらを優先するか確認してください。',
        );
        break;
      }
    }
  }

  void _appendLiveWaitDecisionWarnings({
    required ScheduleRecalculationRequest request,
    required List<Facility> eligibleFacilities,
    required List<String> warnings,
    required Map<String, int> simulatedWaitMinutesByFacilityId,
  }) {
    final existingByFacilityId = <String, ScheduleItem>{};
    for (final item in request.currentSchedule.items) {
      final facilityId = item.facilityId;
      if (facilityId == null || _end(item) <= request.now.hour * 60 + request.now.minute) {
        continue;
      }
      existingByFacilityId.putIfAbsent(facilityId, () => item);
    }

    final exitMinutes =
        request.settings.exitTimeHour * 60 + request.settings.exitTimeMinute;
    final nowMinutes = request.now.hour * 60 + request.now.minute;

    for (final facility in eligibleFacilities) {
      final existing = existingByFacilityId[facility.id];
      if (existing?.usesPriorityAccessPlanning == true) continue;

      final simulated = simulatedWaitMinutesByFacilityId[facility.id];
      final live = request.waitTimes[facility.id];
      final hasFreshLive = live != null && !live.isStaleAt(request.now);
      final currentWait = simulated ?? (hasFreshLive ? live.waitMinutes : null);
      if (currentWait == null) continue;

      final plannedWait = existing?.standbyWaitMinutes ??
          (existing?.usesPriorityAccessPlanning == true
              ? null
              : existing?.estimatedWaitMinutes);
      if (plannedWait != null) {
        final delta = currentWait - plannedWait;
        if (delta <= -15) {
          warnings.add(
            '${facility.name}は計画$plannedWait分に対して現在$currentWait分で、今すぐ行く候補です（${-delta}分短い）。',
          );
        } else if (delta >= 20) {
          warnings.add(
            '${facility.name}は計画$plannedWait分に対して現在$currentWait分まで増えているため、固定予定に支障がなければ後回し候補です。',
          );
        }
      }

      var latestUsableMinutes = exitMinutes;
      final windows = facility.operatingWindowsFor(request.now);
      if (windows.isNotEmpty) {
        final closes = windows
            .map((window) => window.close.hour * 60 + window.close.minute)
            .where((value) => value > nowMinutes)
            .toList(growable: false);
        if (closes.isNotEmpty) {
          final facilityClose = closes.reduce((a, b) => a > b ? a : b);
          if (facilityClose < latestUsableMinutes) latestUsableMinutes = facilityClose;
        }
      }

      final required = currentWait + facility.durationMinutes;
      final remaining = latestUsableMinutes - nowMinutes;
      if (remaining > 0 && required > remaining) {
        warnings.add(
          '${facility.name}は現在待ち$currentWait分では営業終了・退園までに収まりにくいため、今回は見送り候補です。',
        );
      } else if (remaining > 0 && remaining <= 120) {
        warnings.add(
          '${facility.name}は利用可能時間が残り約$remaining分のため、後回しにし過ぎない候補です。',
        );
      }
    }
  }

  bool _isUnavailable(LiveOperatingStatus? status) {
    if (status == null) {
      return false;
    }
    return status.state != LiveOperatingState.operating &&
        status.state != LiveOperatingState.unknown;
  }

  bool _isProtectedFutureItem({
    required ScheduleItem item,
    required Facility? facility,
    required PlanPreference? preference,
    bool released = false,
  }) {
    if (released) return false;
    if (item.type == ScheduleItemType.breakfast ||
        item.type == ScheduleItemType.lunch ||
        item.type == ScheduleItemType.dinner) {
      return true;
    }

    if (item.id.startsWith('manual_repeat_') ||
        item.id.startsWith('intentional_free_time_')) {
      return true;
    }

    if (facility != null &&
        (facility.category == FacilityCategory.show ||
            facility.category == FacilityCategory.parade)) {
      return true;
    }

    return preference?.fixedTimeStatus == FixedTimeStatus.confirmed;
  }

  ScheduleItem _shiftScheduleItem(
    ScheduleItem item, {
    required int startMinutes,
    required int endMinutes,
    int? liveWaitMinutes,
    String? liveWaitSourceLabel,
  }) {
    return ScheduleItem(
      id: item.id,
      title: item.title,
      type: item.type,
      startHour: startMinutes ~/ 60,
      startMinute: startMinutes % 60,
      endHour: endMinutes ~/ 60,
      endMinute: endMinutes % 60,
      facilityId: item.facilityId,
      reason: item.reason == null
          ? '当日の状況を反映し、残り時間へ再配置しました。'
          : '${_sanitizeLegacyReason(item.reason)} 当日の状況を反映し、残り時間へ再配置しました。',
      note: item.note,
      estimatedWaitMinutes: liveWaitMinutes ?? item.estimatedWaitMinutes,
      experienceMinutes: item.experienceMinutes,
      waitEstimateSource: liveWaitMinutes == null
          ? item.waitEstimateSource
          : '当日${liveWaitSourceLabel ?? '待ち時間'}を再最適化へ反映',
      accessMethod: item.accessMethod,
      usesVacationPackageUnlimited: item.usesVacationPackageUnlimited,
      standbyWaitMinutes: liveWaitMinutes ?? item.standbyWaitMinutes,
      priorityAccessBufferMinutes: item.priorityAccessBufferMinutes,
    );
  }

  String? _sanitizeLegacyReason(String? reason) {
    if (reason == null) return null;
    return reason
        .replaceAll('PP代替', 'DPA対象状況')
        .replaceAll('PP利用可能時', 'DPA対象時')
        .replaceAll('PPと待ち時間', 'DPA対象状況と待ち時間');
  }

  bool _usesPriorityAccessPlanning(ScheduleItem item) {
    if (item.usesPriorityAccessPlanning) return true;
    final source = item.waitEstimateSource?.trim() ?? '';
    return source.contains('バケーションパッケージ乗り放題') ||
        source.contains('バケパ乗り放題') ||
        source.contains('優先入口') ||
        source.contains('DPA') ||
        source.contains('プライオリティ');
  }

  bool _rangesOverlap(
    int leftStart,
    int leftEnd,
    int rightStart,
    int rightEnd,
  ) {
    return leftStart < rightEnd && leftEnd > rightStart;
  }

  ScheduleItem? _nextProtectedFuture({
    required ScheduleRecalculationRequest request,
    required List<ScheduleItem> items,
    required int nowMinutes,
  }) {
    final preferenceById = {
      for (final preference in request.preferences)
        preference.facilityId: preference,
    };
    final facilityById = {
      for (final facility in request.facilities) facility.id: facility,
    };
    final candidates = items.where((item) {
      if (_start(item) <= nowMinutes) return false;
      final facilityId = item.facilityId;
      if (facilityId != null &&
          _isUnavailable(request.operatingStatuses[facilityId])) {
        return false;
      }
      return _isProtectedFutureItem(
        item: item,
        facility: facilityId == null ? null : facilityById[facilityId],
        preference: facilityId == null ? null : preferenceById[facilityId],
        released: facilityId != null &&
            request.releasedFacilityIds.contains(facilityId),
      );
    }).toList(growable: false)
      ..sort((a, b) => _start(a).compareTo(_start(b)));
    return candidates.isEmpty ? null : candidates.first;
  }

  Facility? _latestFacility({
    required List<ScheduleItem> preserved,
    required List<Facility> facilities,
  }) {
    final facilityItems = preserved
        .where((item) => item.facilityId != null)
        .toList(growable: false)
      ..sort((a, b) => _end(b).compareTo(_end(a)));
    if (facilityItems.isEmpty) return null;
    return _facilityById(facilities, facilityItems.first.facilityId);
  }

  Facility? _facilityById(List<Facility> facilities, String? facilityId) {
    if (facilityId == null) return null;
    for (final facility in facilities) {
      if (facility.id == facilityId) return facility;
    }
    return null;
  }

  List<ScheduleChange> _buildChanges(
    DaySchedule before,
    DaySchedule after,
    Set<String> preservedKeys,
  ) {
    final beforeByKey = {for (final item in before.items) _key(item): item};
    final afterByKey = {for (final item in after.items) _key(item): item};
    final keys = {...beforeByKey.keys, ...afterByKey.keys}.toList()..sort();
    final changes = <ScheduleChange>[];

    for (final key in keys) {
      final oldItem = beforeByKey[key];
      final newItem = afterByKey[key];
      if (oldItem == null && newItem != null) {
        changes.add(
          ScheduleChange(
            key: key,
            type: ScheduleChangeType.added,
            reason: '残り時間へ新たに配置しました。',
            afterItem: newItem,
          ),
        );
      } else if (oldItem != null && newItem == null) {
        changes.add(
          ScheduleChange(
            key: key,
            type: ScheduleChangeType.removed,
            reason: '営業状態・待ち時間・時間不足のいずれかにより配置できませんでした。',
            beforeItem: oldItem,
          ),
        );
      } else if (oldItem != null && newItem != null) {
        final moved =
            _start(oldItem) != _start(newItem) ||
            _end(oldItem) != _end(newItem);
        changes.add(
          ScheduleChange(
            key: key,
            type: moved
                ? ScheduleChangeType.moved
                : ScheduleChangeType.unchanged,
            reason: preservedKeys.contains(key)
                ? '完了済み・進行中・確定固定予定として維持しました。'
                : moved
                ? '残り予定を再配置しました。'
                : '変更はありません。',
            beforeItem: oldItem,
            afterItem: newItem,
          ),
        );
      }
    }
    return changes;
  }

  int _start(ScheduleItem item) => item.startHour * 60 + item.startMinute;
  int _end(ScheduleItem item) => item.endHour * 60 + item.endMinute;
  String _key(ScheduleItem item) =>
      item.facilityId ?? '${item.type.name}:${item.id}';
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
