import '../entities/day_schedule.dart';
import '../entities/facility.dart';
import '../entities/live_operating_status.dart';
import '../entities/plan_preference.dart';
import '../entities/schedule_change.dart';
import '../entities/schedule_item.dart';
import '../entities/schedule_recalculation_request.dart';
import '../entities/schedule_recalculation_result.dart';
import '../entities/replanning_context.dart';
import '../enums/facility_category.dart';
import '../enums/fixed_time_status.dart';
import '../enums/schedule_change_type.dart';
import '../enums/schedule_item_type.dart';
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

    final preserved = request.currentSchedule.items
        .where((item) {
          final start = _start(item);
          final end = _end(item);
          if (item.type == ScheduleItemType.entry ||
              item.type == ScheduleItemType.exit) {
            return true;
          }

          // Past actions are facts and must never be rewritten.
          if (end <= nowMinutes) {
            return true;
          }

          final facilityId = item.facilityId;
          final unavailable = facilityId != null &&
              _isUnavailable(request.operatingStatuses[facilityId]);

          // A currently running activity is normally protected, but a facility
          // that has just gone down must be released so the remaining plan can
          // recover from the disruption.
          if (start <= nowMinutes && nowMinutes < end) {
            if (item.type == ScheduleItemType.breakTime) {
              return false;
            }
            return !unavailable;
          }

          if (unavailable) {
            return false;
          }

          final facility =
              facilityId == null ? null : facilityById[facilityId];
          final preference =
              facilityId == null ? null : preferenceById[facilityId];

          return _isProtectedFutureItem(
            item: item,
            facility: facility,
            preference: preference,
          );
        })
        .toList(growable: false);

    final preservedFacilityIds = preserved
        .map((item) => item.facilityId)
        .whereType<String>()
        .toSet();
    final warnings = <String>[];

    final eligibleFacilities = request.facilities
        .where((facility) {
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
          // Attractions are not excluded by a fixed 15/30/60-minute user
          // ceiling. Their live wait is an input to replanning, while the
          // decision itself is made relative to the attraction's collected
          // wait history and the rest of the day's constraints.
          if (facility.category != FacilityCategory.attraction &&
              preference != null &&
              liveWait != null &&
              !preference.waitTolerance.allows(liveWait.waitMinutes)) {
            warnings.add(
              '${facility.name}は待ち時間${liveWait.waitMinutes}分が許容範囲を超えたため後回し候補から除外しました。',
            );
            return false;
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

    final currentFacility = _latestFacility(
      preserved: preserved,
      facilities: request.facilities,
    );
    final nextFixed = _nextProtectedFuture(
      request: request,
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
              _start(item) > nowMinutes &&
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
      if (end > exitMinutes) continue;

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

    final exitItem = request.currentSchedule.items
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


  bool _isUnavailable(LiveOperatingStatus? status) {
    if (status == null) return false;
    return status.state != LiveOperatingState.operating &&
        status.state != LiveOperatingState.unknown;
  }

  bool _isProtectedFutureItem({
    required ScheduleItem item,
    required Facility? facility,
    required PlanPreference? preference,
  }) {
    if (item.type == ScheduleItemType.breakfast ||
        item.type == ScheduleItemType.lunch ||
        item.type == ScheduleItemType.dinner) {
      return true;
    }

    if (item.id.startsWith('manual_repeat_')) {
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
          : '${item.reason} 当日の状況を反映し、残り時間へ再配置しました。',
      note: item.note,
      estimatedWaitMinutes: liveWaitMinutes ?? item.estimatedWaitMinutes,
      experienceMinutes: item.experienceMinutes,
      waitEstimateSource: liveWaitMinutes == null
          ? item.waitEstimateSource
          : '当日${liveWaitSourceLabel ?? '待ち時間'}を再最適化へ反映',
    );
  }

  bool _usesPriorityAccessPlanning(ScheduleItem item) {
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
    required int nowMinutes,
  }) {
    final preferenceById = {
      for (final preference in request.preferences)
        preference.facilityId: preference,
    };
    final facilityById = {
      for (final facility in request.facilities) facility.id: facility,
    };
    final candidates = request.currentSchedule.items.where((item) {
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
