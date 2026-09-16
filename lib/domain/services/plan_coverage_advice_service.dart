import '../entities/facility.dart';
import '../entities/plan_coverage_advice.dart';

class DpaOrderMetric {
  const DpaOrderMetric({
    required this.facilityId,
    this.estimatedSavedMinutes,
  });

  final String facilityId;
  final int? estimatedSavedMinutes;
}

class PlanCoverageAdviceService {
  const PlanCoverageAdviceService();

  PlanCoverageAdvice build({
    required List<Facility> desiredFacilities,
    required Set<String> currentScheduledFacilityIds,
    required List<PlanCoverageScenario> scenarios,
    required List<DpaOrderMetric> orderedDpaMetrics,
  }) {
    final desiredIds = desiredFacilities.map((facility) => facility.id).toSet();
    final currentCount = desiredIds.intersection(currentScheduledFacilityIds).length;

    int? minimumDpaCountForAll;
    for (final scenario in scenarios) {
      final covered = scenario.scheduledDesiredCount;
      if (covered == desiredIds.length) {
        minimumDpaCountForAll = scenario.dpaCount;
        break;
      }
    }

    final unmet = <UnmetPlanFacilityAdvice>[];
    for (final facility in desiredFacilities) {
      if (currentScheduledFacilityIds.contains(facility.id)) continue;

      int? rescuedAt;
      for (final scenario in scenarios) {
        if (scenario.dpaCount <= 0) continue;
        if (scenario.scheduledFacilityIds.contains(facility.id)) {
          rescuedAt = scenario.dpaCount;
          break;
        }
      }

      final reason = rescuedAt != null
          ? '現在の通常待機中心プランでは未採用ですが、DPAを$rescuedAt個まで使うシミュレーションではプランに入ります。'
          : facility.supportsDpa
              ? '現在の固定予定・移動・待ち時間を含む一日最適化では未採用です。DPAを増やしても今回のシミュレーション上は採用されませんでした。'
              : '現在の固定予定・移動・待ち時間を含む一日最適化では未採用です。この施設自体はアトラクションDPA対象ではありません。';

      unmet.add(
        UnmetPlanFacilityAdvice(
          facilityId: facility.id,
          name: facility.name,
          supportsDpa: facility.supportsDpa,
          reason: reason,
          firstRescuedAtDpaCount: rescuedAt,
        ),
      );
    }

    final facilityById = {for (final facility in desiredFacilities) facility.id: facility};
    final unmetIds = unmet.map((item) => item.facilityId).toSet();
    final order = <DpaAcquisitionAdvice>[];
    for (final metric in orderedDpaMetrics) {
      // DPA advice is a rescue recommendation for wishes that the finalized
      // normal plan still misses. Never recommend buying DPA for a facility
      // that is already scheduled in the final plan.
      if (!unmetIds.contains(metric.facilityId)) continue;
      final facility = facilityById[metric.facilityId];
      if (facility == null || !facility.supportsDpa) continue;
      order.add(
        DpaAcquisitionAdvice(
          order: order.length + 1,
          facilityId: facility.id,
          name: facility.name,
          estimatedSavedMinutes: metric.estimatedSavedMinutes,
          reason: metric.estimatedSavedMinutes != null && metric.estimatedSavedMinutes! > 0
              ? '通常待機との差で約${metric.estimatedSavedMinutes}分の短縮余地があり、希望達成数と時間効率を優先した順です。'
              : '希望達成数・優先度・通常待機の負担をまとめて比較したPlanner推奨順です。',
        ),
      );
    }

    return PlanCoverageAdvice(
      totalDesiredCount: desiredFacilities.length,
      currentScheduledCount: currentCount,
      unmetFacilities: List.unmodifiable(unmet),
      scenarios: List.unmodifiable(scenarios),
      dpaAcquisitionOrder: List.unmodifiable(order),
      simulatedMaxDpaCount: scenarios.isEmpty ? 0 : scenarios.last.dpaCount,
      minimumDpaCountForAll: minimumDpaCountForAll,
    );
  }
}
