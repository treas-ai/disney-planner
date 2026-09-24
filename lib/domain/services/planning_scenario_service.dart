import '../entities/plan_coverage_advice.dart';
import '../entities/planning_scenario.dart';
import 'official_dpa_price_catalog.dart';

class PlanningScenarioService {
  const PlanningScenarioService({
    this.priceCatalog = const OfficialDpaPriceCatalog(),
  });

  final OfficialDpaPriceCatalog priceCatalog;

  PlanningScenarioSet fromCoverageAdvice(
    PlanCoverageAdvice advice, {
    DateTime? visitDate,
    int numberOfPeople = 1,
  }) {
    final scenarios = <PlanningScenario>[];
    var allPriced = visitDate != null;
    for (final source in advice.scenarios) {
      int? cost;
      var priced = source.dpaCount == 0;
      if (source.dpaCount == 0) {
        cost = 0;
      } else if (visitDate != null) {
        var sumPerPerson = 0;
        priced = true;
        for (final id in source.selectedDpaFacilityIds) {
          final quote = priceCatalog.quote(id, visitDate);
          if (quote == null || !quote.validOnVisitDate) {
            priced = false;
            break;
          }
          sumPerPerson += quote.pricePerPersonYen;
        }
        if (priced) cost = sumPerPerson * numberOfPeople.clamp(1, 10).toInt();
      }
      allPriced = allPriced && priced;
      scenarios.add(
        PlanningScenario(
          kind: source.dpaCount == 0
              ? PlanningScenarioKind.noExtraCost
              : PlanningScenarioKind.dpa,
          scheduledDesiredCount: source.scheduledDesiredCount,
          totalDesiredCount: advice.totalDesiredCount,
          dpaCount: source.dpaCount,
          selectedDpaFacilityIds:
              List<String>.unmodifiable(source.selectedDpaFacilityIds),
          extraCostYen: cost,
          costDataAvailable: priced,
          totalWaitMinutes: source.totalWaitMinutes,
          totalFreeMinutes: source.totalFreeMinutes,
          totalMovementMinutes: source.totalMovementMinutes,
          hardScheduledDesiredCount: source.hardScheduledDesiredCount,
          totalHardDesiredCount: source.totalHardDesiredCount,
        ),
      );
    }
    return PlanningScenarioSet(
      scenarios: List<PlanningScenario>.unmodifiable(scenarios),
      costComparisonReady: allPriced,
    );
  }
  PlanningScenario? recommend(
    PlanningScenarioSet set, {
    required PlanningBudgetMode budgetMode,
    required int maxExtraBudgetYen,
  }) {
    if (set.scenarios.isEmpty) return null;
    final baseline = set.scenarios.firstWhere(
      (item) => item.kind == PlanningScenarioKind.noExtraCost,
      orElse: () => set.scenarios.first,
    );
    if (budgetMode == PlanningBudgetMode.noExtraCost) return baseline;

    final priced = set.scenarios
        .where((item) => item.costDataAvailable && item.extraCostYen != null)
        .toList(growable: false);
    if (priced.isEmpty) return baseline;

    Iterable<PlanningScenario> candidates = priced;
    if (budgetMode == PlanningBudgetMode.maxExtraBudget) {
      candidates = priced.where(
        (item) => item.extraCostYen! <= maxExtraBudgetYen,
      );
      if (candidates.isEmpty) return baseline;
    }
    if (budgetMode == PlanningBudgetMode.lowCost) {
      final improved = priced.where(
        (item) => item.scheduledDesiredCount > baseline.scheduledDesiredCount,
      );
      if (improved.isEmpty) return baseline;
      return improved.reduce((left, right) {
        final costCompare = left.extraCostYen!.compareTo(right.extraCostYen!);
        if (costCompare != 0) return costCompare < 0 ? left : right;
        if (left.scheduledDesiredCount != right.scheduledDesiredCount) {
          return left.scheduledDesiredCount > right.scheduledDesiredCount
              ? left
              : right;
        }
        return (left.totalWaitMinutes ?? 1 << 30) <=
                (right.totalWaitMinutes ?? 1 << 30)
            ? left
            : right;
      });
    }

    return candidates.reduce((left, right) {
      if (left.scheduledDesiredCount != right.scheduledDesiredCount) {
        return left.scheduledDesiredCount > right.scheduledDesiredCount
            ? left
            : right;
      }
      final leftWait = left.totalWaitMinutes ?? 1 << 30;
      final rightWait = right.totalWaitMinutes ?? 1 << 30;
      if (leftWait != rightWait) return leftWait < rightWait ? left : right;
      return left.extraCostYen! <= right.extraCostYen! ? left : right;
    });
  }

}
