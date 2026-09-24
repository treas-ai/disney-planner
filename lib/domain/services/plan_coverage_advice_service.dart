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
    Map<String, int>? currentScheduledFacilityCounts,
    required int currentScheduledDesiredCount,
    required List<PlanCoverageScenario> scenarios,
    required List<DpaOrderMetric> orderedDpaMetrics,
  }) {
    final currentCount = currentScheduledDesiredCount.clamp(0, desiredFacilities.length);

    int? minimumDpaCountForAll;
    for (final scenario in scenarios) {
      final covered = scenario.scheduledDesiredCount;
      if (covered >= desiredFacilities.length) {
        minimumDpaCountForAll = scenario.dpaCount;
        break;
      }
    }

    final requestedCounts = <String, int>{};
    final facilityById = <String, Facility>{};
    for (final facility in desiredFacilities) {
      requestedCounts[facility.id] = (requestedCounts[facility.id] ?? 0) + 1;
      facilityById.putIfAbsent(facility.id, () => facility);
    }
    final scheduledCounts = currentScheduledFacilityCounts ??
        {for (final id in currentScheduledFacilityIds) id: 1};

    final unmet = <UnmetPlanFacilityAdvice>[];
    for (final entry in requestedCounts.entries) {
      final facility = facilityById[entry.key]!;
      final requestedCount = entry.value;
      final scheduledCount = scheduledCounts[facility.id] ?? 0;
      if (scheduledCount >= requestedCount) continue;
      final missingCount = requestedCount - scheduledCount;

      int? rescuedAt;
      // Scenario facility IDs are sets and therefore cannot prove that an
      // additional occurrence of an already-scheduled repeat wish was rescued.
      // Only attach a rescue stage when the facility is currently absent.
      if (scheduledCount == 0) {
        for (final scenario in scenarios) {
          if (scenario.dpaCount <= 0) continue;
          if (scenario.scheduledFacilityIds.contains(facility.id)) {
            rescuedAt = scenario.dpaCount;
            break;
          }
        }
      }

      final partialPrefix = requestedCount > 1
          ? '$requestedCount回希望のうち$scheduledCount回達成、あと$missingCount回です。'
          : '';
      final reason = rescuedAt != null
          ? '$partialPrefix現在の通常待機中心プランでは希望回数を満たしていませんが、DPAを$rescuedAt個まで使うシミュレーションでは改善します。'
          : facility.supportsDpa
              ? '$partialPrefix現在の固定予定・移動・待ち時間を含む一日最適化では希望回数を満たせません。DPAを増やしても今回のシミュレーション上は全回数を満たしませんでした。'
              : '$partialPrefix現在の固定予定・移動・待ち時間を含む一日最適化では希望回数を満たせません。この施設自体はアトラクションDPA対象ではありません。';

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
