import '../entities/day_schedule.dart';
import '../entities/event_impact.dart';
import '../entities/facility.dart';
import '../entities/plan_optimization_dimension.dart';
import '../entities/plan_optimization_result.dart';
import '../entities/plan_preference.dart';
import '../entities/schedule_item.dart';
import '../entities/smart_schedule_metrics.dart';
import '../entities/trip_settings.dart';
import '../entities/wait_time_prediction.dart';
import '../enums/facility_category.dart';
import '../enums/fixed_time_status.dart';
import '../enums/priority_level.dart';
import '../enums/schedule_item_type.dart';
import 'event_impact_engine.dart';
import 'plan_optimization_engine.dart';

class RuleBasedPlanOptimizationEngine implements PlanOptimizationEngine {
  const RuleBasedPlanOptimizationEngine({
    this.eventImpactEngine = const EventImpactEngine(),
  });

  final EventImpactEngine eventImpactEngine;

  @override
  PlanOptimizationResult optimize({
    required DaySchedule schedule,
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
    required Map<String, WaitTimePrediction> predictions,
    required TripSettings settings,
    List<EventImpact> eventImpacts = const [],
  }) {
    final facilityById = {
      for (final facility in facilities) facility.id: facility,
    };
    final preferenceById = {
      for (final preference in preferences) preference.facilityId: preference,
    };

    final fixedItems = <ScheduleItem>[];
    final flexibleSlots = <ScheduleItem>[];

    for (final item in schedule.items) {
      if (_isProtectedItem(item, preferenceById)) {
        fixedItems.add(item);
      } else {
        flexibleSlots.add(item);
      }
    }

    final slotOrder = [...flexibleSlots]
      ..sort((left, right) => _start(left).compareTo(_start(right)));

    final remaining = [...flexibleSlots];
    final optimizedItems = <ScheduleItem>[...fixedItems];
    String? previousAreaId;

    for (final slot in slotOrder) {
      final selected = _selectBestCandidate(
        candidates: remaining,
        slot: slot,
        previousAreaId: previousAreaId,
        facilityById: facilityById,
        preferenceById: preferenceById,
        predictions: predictions,
        settings: settings,
        eventImpacts: eventImpacts,
      );

      remaining.remove(selected);
      final facility = selected.facilityId == null
          ? null
          : facilityById[selected.facilityId!];

      optimizedItems.add(
        ScheduleItem(
          id: selected.id,
          title: selected.title,
          type: selected.type,
          startHour: slot.startHour,
          startMinute: slot.startMinute,
          endHour: slot.endHour,
          endMinute: slot.endMinute,
          facilityId: selected.facilityId,
          reason: _buildOptimizationReason(
            facility: facility,
            preference: selected.facilityId == null
                ? null
                : preferenceById[selected.facilityId!],
            prediction: selected.facilityId == null
                ? null
                : predictions[selected.facilityId!],
            previousAreaId: previousAreaId,
            slotMinutes: _start(slot),
            settings: settings,
            eventImpacts: eventImpacts,
          ),
          note: selected.note,
        ),
      );

      previousAreaId = facility?.areaId ?? previousAreaId;
    }

    optimizedItems.sort((left, right) => _start(left).compareTo(_start(right)));

    final afterSchedule = DaySchedule(
      id: 'smart_${DateTime.now().millisecondsSinceEpoch}',
      parkId: schedule.parkId,
      items: List<ScheduleItem>.unmodifiable(optimizedItems),
      createdAt: DateTime.now(),
    );

    final beforeMetrics = _metrics(
      schedule: schedule,
      facilityById: facilityById,
      preferenceById: preferenceById,
      predictions: predictions,
      settings: settings,
      eventImpacts: eventImpacts,
    );
    final afterMetrics = _metrics(
      schedule: afterSchedule,
      facilityById: facilityById,
      preferenceById: preferenceById,
      predictions: predictions,
      settings: settings,
      eventImpacts: eventImpacts,
    );

    final beforeScore = _score(beforeMetrics);
    final afterScore = _score(afterMetrics);

    final dimensions = <PlanOptimizationDimension>[
      PlanOptimizationDimension(
        label: '移動効率',
        score: (100 - afterMetrics.areaTransitions * 12).clamp(0, 100),
        message:
            'エリア移動 ${beforeMetrics.areaTransitions}回 → ${afterMetrics.areaTransitions}回',
      ),
      PlanOptimizationDimension(
        label: '待ち時間効率',
        score: (100 - afterMetrics.predictedWaitMinutes ~/ 4).clamp(0, 100),
        message: predictions.isEmpty
            ? '予測データ不足のため参考評価です。'
            : '予測待ち時間合計 約${afterMetrics.predictedWaitMinutes}分',
      ),
      PlanOptimizationDimension(
        label: '雨天対応',
        score: settings.isRainy
            ? (100 - afterMetrics.outdoorItemsInRain * 20).clamp(0, 100)
            : 100,
        message: settings.isRainy
            ? '屋外予定 ${beforeMetrics.outdoorItemsInRain}件 → '
                  '${afterMetrics.outdoorItemsInRain}件'
            : '雨天設定ではないため減点なしです。',
      ),
      PlanOptimizationDimension(
        label: 'イベント回避',
        score: (100 - afterMetrics.eventAffectedItems * 18).clamp(0, 100),
        message:
            'イベント影響予定 ${beforeMetrics.eventAffectedItems}件 → '
            '${afterMetrics.eventAffectedItems}件',
      ),
      PlanOptimizationDimension(
        label: '歩行負担',
        score: (100 - afterMetrics.longWalkingStreaks * 15).clamp(0, 100),
        message:
            '連続エリア移動 ${beforeMetrics.longWalkingStreaks}回 → '
            '${afterMetrics.longWalkingStreaks}回',
      ),
      const PlanOptimizationDimension(
        label: '固定予定・食事保護',
        score: 100,
        message: '確定予定と朝食・昼食・夕食の時刻は変更していません。',
      ),
    ];

    final recommendations = <String>[
      if (afterMetrics.areaTransitions < beforeMetrics.areaTransitions)
        'エリア移動を'
            '${beforeMetrics.areaTransitions - afterMetrics.areaTransitions}回削減しました。',
      if (afterMetrics.predictedWaitMinutes <
          beforeMetrics.predictedWaitMinutes)
        '予測待ち時間が増える施設を早い時間帯へ移動しました。',
      if (settings.isRainy &&
          afterMetrics.outdoorItemsInRain < beforeMetrics.outdoorItemsInRain)
        '雨天を考慮し、屋内施設を優先しました。',
      if (afterMetrics.eventAffectedItems < beforeMetrics.eventAffectedItems)
        'ショー・パレード等のイベント影響を避ける順番へ変更しました。',
      if (afterMetrics.longWalkingStreaks < beforeMetrics.longWalkingStreaks)
        '連続する長距離移動を減らし、歩行負担を軽減しました。',
      '確定済みのショー、予約、DPA等と食事予定は維持します。',
      if (afterScore <= beforeScore) '現在のプランは既に良好です。大きな改善効果は見込めません。',
    ];

    return PlanOptimizationResult(
      beforeSchedule: schedule,
      afterSchedule: afterSchedule,
      beforeScore: beforeScore,
      afterScore: afterScore,
      beforeMetrics: beforeMetrics,
      afterMetrics: afterMetrics,
      dimensions: List<PlanOptimizationDimension>.unmodifiable(dimensions),
      recommendations: List<String>.unmodifiable(recommendations),
      createdAt: DateTime.now(),
    );
  }

  bool _isProtectedItem(
    ScheduleItem item,
    Map<String, PlanPreference> preferenceById,
  ) {
    if (item.type == ScheduleItemType.entry ||
        item.type == ScheduleItemType.exit ||
        item.type == ScheduleItemType.breakfast ||
        item.type == ScheduleItemType.lunch ||
        item.type == ScheduleItemType.dinner ||
        item.type == ScheduleItemType.breakTime) {
      return true;
    }

    final facilityId = item.facilityId;
    if (facilityId == null) {
      return false;
    }

    return preferenceById[facilityId]?.fixedTimeStatus ==
        FixedTimeStatus.confirmed;
  }

  ScheduleItem _selectBestCandidate({
    required List<ScheduleItem> candidates,
    required ScheduleItem slot,
    required String? previousAreaId,
    required Map<String, Facility> facilityById,
    required Map<String, PlanPreference> preferenceById,
    required Map<String, WaitTimePrediction> predictions,
    required TripSettings settings,
    required List<EventImpact> eventImpacts,
  }) {
    return candidates.reduce((best, candidate) {
      final bestScore = _candidateScore(
        item: best,
        slotMinutes: _start(slot),
        previousAreaId: previousAreaId,
        facilityById: facilityById,
        preferenceById: preferenceById,
        predictions: predictions,
        settings: settings,
        eventImpacts: eventImpacts,
      );
      final candidateScore = _candidateScore(
        item: candidate,
        slotMinutes: _start(slot),
        previousAreaId: previousAreaId,
        facilityById: facilityById,
        preferenceById: preferenceById,
        predictions: predictions,
        settings: settings,
        eventImpacts: eventImpacts,
      );

      if (candidateScore != bestScore) {
        return candidateScore > bestScore ? candidate : best;
      }

      return candidate.title.compareTo(best.title) < 0 ? candidate : best;
    });
  }

  int _candidateScore({
    required ScheduleItem item,
    required int slotMinutes,
    required String? previousAreaId,
    required Map<String, Facility> facilityById,
    required Map<String, PlanPreference> preferenceById,
    required Map<String, WaitTimePrediction> predictions,
    required TripSettings settings,
    required List<EventImpact> eventImpacts,
  }) {
    final facilityId = item.facilityId;
    if (facilityId == null) {
      return 0;
    }

    final facility = facilityById[facilityId];
    if (facility == null) {
      return 0;
    }

    final preference = preferenceById[facilityId];
    final prediction = predictions[facilityId];
    var score = (preference?.priority.value ?? facility.priority.value) * 20;

    if (previousAreaId != null && previousAreaId == facility.areaId) {
      score += 35;
    } else if (previousAreaId != null) {
      score -= 12;
    }

    if (prediction != null) {
      score += (prediction.predictedMinutes ?? 0).clamp(0, 120) ~/ 3;
    }

    if (settings.isRainy) {
      score += facility.isIndoor ? 30 : -35;
    }

    if (facility.category == FacilityCategory.show ||
        facility.category == FacilityCategory.parade) {
      score += 12;
    }

    final activeImpacts = eventImpactEngine.activeImpacts(
      atMinutes: slotMinutes,
      impacts: eventImpacts,
    );
    if (activeImpacts.any((impact) => impact.affectsArea(facility.areaId))) {
      score -= 45;
    }

    final targetDate = settings.visitDate ?? DateTime.now();
    if (!facility.canAddToPlanAt(targetDate)) {
      score -= 1000;
    }

    return score;
  }

  String _buildOptimizationReason({
    required Facility? facility,
    required PlanPreference? preference,
    required WaitTimePrediction? prediction,
    required String? previousAreaId,
    required int slotMinutes,
    required TripSettings settings,
    required List<EventImpact> eventImpacts,
  }) {
    if (facility == null) {
      return 'AIが固定予定との重なりを避けて再配置しました。';
    }

    final reasons = <String>[];

    if (previousAreaId != null && previousAreaId == facility.areaId) {
      reasons.add('同じエリアをまとめて移動を削減');
    }

    final priority = preference?.priority ?? facility.priority;
    if (priority == PriorityLevel.high || priority == PriorityLevel.highest) {
      reasons.add('優先度の高い施設を前倒し');
    }

    if (prediction != null && (prediction.predictedMinutes ?? 0) > 0) {
      reasons.add('予測待ち時間${prediction.predictedMinutes ?? 0}分を考慮');
    }

    if (settings.isRainy && facility.isIndoor) {
      reasons.add('雨天のため屋内施設を優先');
    }

    final affected = eventImpactEngine
        .activeImpacts(atMinutes: slotMinutes, impacts: eventImpacts)
        .any((impact) => impact.affectsArea(facility.areaId));
    if (!affected && eventImpacts.isNotEmpty) {
      reasons.add('イベント影響の少ない時間帯');
    }

    if (reasons.isEmpty) {
      return 'AIが移動・優先度・待ち時間を総合して再配置しました。';
    }

    return '${reasons.join('、')}。';
  }

  SmartScheduleMetrics _metrics({
    required DaySchedule schedule,
    required Map<String, Facility> facilityById,
    required Map<String, PlanPreference> preferenceById,
    required Map<String, WaitTimePrediction> predictions,
    required TripSettings settings,
    required List<EventImpact> eventImpacts,
  }) {
    String? previousArea;
    var transitions = 0;
    var consecutiveTransitions = 0;
    var longWalkingStreaks = 0;
    var predictedWait = 0;
    var highPriorityEarly = 0;
    var outdoorInRain = 0;
    var eventAffected = 0;

    for (var index = 0; index < schedule.items.length; index++) {
      final item = schedule.items[index];
      final facilityId = item.facilityId;
      if (facilityId == null) {
        consecutiveTransitions = 0;
        continue;
      }

      final facility = facilityById[facilityId];
      if (facility == null) {
        continue;
      }

      predictedWait += predictions[facilityId]?.predictedMinutes ?? 0;

      if (settings.isRainy && !facility.isIndoor) {
        outdoorInRain++;
      }

      final priority =
          preferenceById[facilityId]?.priority ?? facility.priority;
      if (index < 5 &&
          (priority == PriorityLevel.high ||
              priority == PriorityLevel.highest)) {
        highPriorityEarly++;
      }

      if (previousArea != null && previousArea != facility.areaId) {
        transitions++;
        consecutiveTransitions++;
        if (consecutiveTransitions >= 3) {
          longWalkingStreaks++;
        }
      } else {
        consecutiveTransitions = 0;
      }
      previousArea = facility.areaId;

      if (eventImpactEngine
          .activeImpacts(atMinutes: _start(item), impacts: eventImpacts)
          .any((impact) => impact.affectsArea(facility.areaId))) {
        eventAffected++;
      }
    }

    return SmartScheduleMetrics(
      areaTransitions: transitions,
      predictedWaitMinutes: predictedWait,
      highPriorityEarlyCount: highPriorityEarly,
      outdoorItemsInRain: outdoorInRain,
      eventAffectedItems: eventAffected,
      longWalkingStreaks: longWalkingStreaks,
    );
  }

  int _score(SmartScheduleMetrics metrics) {
    final score =
        100 -
        metrics.areaTransitions * 5 -
        metrics.predictedWaitMinutes ~/ 20 -
        metrics.outdoorItemsInRain * 8 -
        metrics.eventAffectedItems * 8 -
        metrics.longWalkingStreaks * 6 +
        metrics.highPriorityEarlyCount * 3;

    return score.clamp(0, 100);
  }

  int _start(ScheduleItem item) => item.startHour * 60 + item.startMinute;
}
