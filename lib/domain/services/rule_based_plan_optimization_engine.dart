import '../entities/day_schedule.dart';
import '../entities/facility.dart';
import '../entities/plan_optimization_dimension.dart';
import '../entities/plan_optimization_result.dart';
import '../entities/plan_preference.dart';
import '../entities/schedule_item.dart';
import '../entities/wait_time_prediction.dart';
import '../enums/fixed_time_status.dart';
import '../enums/schedule_item_type.dart';
import 'plan_optimization_engine.dart';

class RuleBasedPlanOptimizationEngine implements PlanOptimizationEngine {
  const RuleBasedPlanOptimizationEngine();

  @override
  PlanOptimizationResult optimize({
    required DaySchedule schedule,
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
    required Map<String, WaitTimePrediction> predictions,
  }) {
    final facilityById = {
      for (final facility in facilities) facility.id: facility,
    };
    final preferenceById = {
      for (final preference in preferences) preference.facilityId: preference,
    };

    final beforeScore = _score(
      schedule: schedule,
      facilityById: facilityById,
      preferenceById: preferenceById,
      predictions: predictions,
    );

    final fixedItems = <ScheduleItem>[];
    final flexibleSlots = <ScheduleItem>[];
    for (final item in schedule.items) {
      final preference = item.facilityId == null
          ? null
          : preferenceById[item.facilityId!];
      final isFixed =
          item.type == ScheduleItemType.entry ||
          item.type == ScheduleItemType.exit ||
          preference?.fixedTimeStatus == FixedTimeStatus.confirmed;
      if (isFixed) {
        fixedItems.add(item);
      } else {
        flexibleSlots.add(item);
      }
    }

    final optimizedSources = [...flexibleSlots]
      ..sort((left, right) {
        final leftFacility = left.facilityId == null
            ? null
            : facilityById[left.facilityId!];
        final rightFacility = right.facilityId == null
            ? null
            : facilityById[right.facilityId!];
        final areaCompare = (leftFacility?.areaId ?? '').compareTo(
          rightFacility?.areaId ?? '',
        );
        if (areaCompare != 0) {
          return areaCompare;
        }
        final leftPriority = left.facilityId == null
            ? 0
            : preferenceById[left.facilityId!]?.priority.value ?? 0;
        final rightPriority = right.facilityId == null
            ? 0
            : preferenceById[right.facilityId!]?.priority.value ?? 0;
        if (leftPriority != rightPriority) {
          return rightPriority.compareTo(leftPriority);
        }
        final leftWait = left.facilityId == null
            ? 0
            : predictions[left.facilityId!]?.predictedMinutes ?? 0;
        final rightWait = right.facilityId == null
            ? 0
            : predictions[right.facilityId!]?.predictedMinutes ?? 0;
        return rightWait.compareTo(leftWait);
      });

    final slotOrder = [...flexibleSlots]
      ..sort((left, right) => _start(left).compareTo(_start(right)));
    final optimizedItems = <ScheduleItem>[...fixedItems];
    for (var index = 0; index < slotOrder.length; index++) {
      final slot = slotOrder[index];
      final source = optimizedSources[index];
      optimizedItems.add(
        ScheduleItem(
          id: source.id,
          title: source.title,
          type: source.type,
          startHour: slot.startHour,
          startMinute: slot.startMinute,
          endHour: slot.endHour,
          endMinute: slot.endMinute,
          facilityId: source.facilityId,
          reason: 'AIがエリア移動・優先度・予測待ち時間を考慮して再配置しました。',
          note: source.note,
        ),
      );
    }
    optimizedItems.sort((left, right) => _start(left).compareTo(_start(right)));

    final afterSchedule = DaySchedule(
      id: 'optimized_${DateTime.now().millisecondsSinceEpoch}',
      parkId: schedule.parkId,
      items: List<ScheduleItem>.unmodifiable(optimizedItems),
      createdAt: DateTime.now(),
    );
    final afterScore = _score(
      schedule: afterSchedule,
      facilityById: facilityById,
      preferenceById: preferenceById,
      predictions: predictions,
    );

    final beforeTransitions = _areaTransitions(schedule, facilityById);
    final afterTransitions = _areaTransitions(afterSchedule, facilityById);
    final predictedWaitTotal = _predictedWaitTotal(afterSchedule, predictions);
    final priorityScore = _priorityScore(afterSchedule, preferenceById);

    final dimensions = <PlanOptimizationDimension>[
      PlanOptimizationDimension(
        label: '移動効率',
        score: (100 - afterTransitions * 12).clamp(0, 100).toInt(),
        message: 'エリア移動 $beforeTransitions回 → $afterTransitions回',
      ),
      PlanOptimizationDimension(
        label: '待ち時間効率',
        score: (100 - predictedWaitTotal ~/ 4).clamp(0, 100).toInt(),
        message: predictions.isEmpty
            ? '予測データ不足のため参考評価です。'
            : '予測待ち時間合計 約$predictedWaitTotal分',
      ),
      PlanOptimizationDimension(
        label: '優先度反映',
        score: priorityScore,
        message: '優先度の高い施設を早い時間帯へ配置しています。',
      ),
      PlanOptimizationDimension(
        label: '固定予定保護',
        score: 100,
        message: '確定固定予定の時刻は変更していません。',
      ),
    ];

    final recommendations = <String>[
      if (afterTransitions < beforeTransitions)
        'エリア移動を${beforeTransitions - afterTransitions}回削減できます。',
      if (predictions.isNotEmpty) 'AI待ち時間予測を利用し、混雑が増える前の利用を優先しました。',
      '確定済みのショー、予約、DPA等はそのまま維持します。',
      if (afterScore <= beforeScore) '現在のプランは既に良好です。大きな並び替え効果は見込めません。',
    ];

    return PlanOptimizationResult(
      beforeSchedule: schedule,
      afterSchedule: afterSchedule,
      beforeScore: beforeScore,
      afterScore: afterScore,
      dimensions: List<PlanOptimizationDimension>.unmodifiable(dimensions),
      recommendations: List<String>.unmodifiable(recommendations),
      createdAt: DateTime.now(),
    );
  }

  int _score({
    required DaySchedule schedule,
    required Map<String, Facility> facilityById,
    required Map<String, PlanPreference> preferenceById,
    required Map<String, WaitTimePrediction> predictions,
  }) {
    final transitions = _areaTransitions(schedule, facilityById);
    final waitTotal = _predictedWaitTotal(schedule, predictions);
    final priority = _priorityScore(schedule, preferenceById);
    final score =
        100 - transitions * 5 - waitTotal ~/ 20 + (priority - 70) ~/ 3;
    return score.clamp(0, 100).toInt();
  }

  int _areaTransitions(
    DaySchedule schedule,
    Map<String, Facility> facilityById,
  ) {
    String? previousArea;
    var transitions = 0;
    for (final item in schedule.items) {
      final facilityId = item.facilityId;
      if (facilityId == null) {
        continue;
      }
      final area = facilityById[facilityId]?.areaId;
      if (area == null || area.isEmpty) {
        continue;
      }
      if (previousArea != null && previousArea != area) {
        transitions++;
      }
      previousArea = area;
    }
    return transitions;
  }

  int _predictedWaitTotal(
    DaySchedule schedule,
    Map<String, WaitTimePrediction> predictions,
  ) {
    var total = 0;
    for (final item in schedule.items) {
      final facilityId = item.facilityId;
      if (facilityId != null) {
        total += predictions[facilityId]?.predictedMinutes ?? 0;
      }
    }
    return total;
  }

  int _priorityScore(
    DaySchedule schedule,
    Map<String, PlanPreference> preferenceById,
  ) {
    final facilityItems = schedule.items
        .where((item) => item.facilityId != null)
        .toList(growable: false);
    if (facilityItems.isEmpty) {
      return 100;
    }
    var weighted = 0.0;
    for (var index = 0; index < facilityItems.length; index++) {
      final priority =
          preferenceById[facilityItems[index].facilityId!]?.priority.value ?? 3;
      final positionWeight = 1 - index / facilityItems.length;
      weighted += priority * positionWeight;
    }
    final maximum = facilityItems.length * 5.0;
    return ((weighted / maximum) * 100).round().clamp(0, 100).toInt();
  }

  int _start(ScheduleItem item) => item.startHour * 60 + item.startMinute;
}
