enum PlanningScenarioKind {
  noExtraCost,
  dpa,
  vacationPackage,
}

enum PlanningBudgetMode {
  noExtraCost,
  lowCost,
  maxExtraBudget,
  fulfillmentFirst,
}

class PlanningScenario {
  const PlanningScenario({
    required this.kind,
    required this.scheduledDesiredCount,
    required this.totalDesiredCount,
    this.dpaCount = 0,
    this.selectedDpaFacilityIds = const <String>[],
    this.extraCostYen,
    this.costDataAvailable = false,
    this.totalWaitMinutes,
    this.totalFreeMinutes,
    this.totalMovementMinutes,
    this.hardScheduledDesiredCount,
    this.totalHardDesiredCount,
  });

  final PlanningScenarioKind kind;
  final int scheduledDesiredCount;
  final int totalDesiredCount;
  final int dpaCount;
  final List<String> selectedDpaFacilityIds;
  final int? extraCostYen;
  final bool costDataAvailable;
  final int? totalWaitMinutes;
  final int? totalFreeMinutes;
  final int? totalMovementMinutes;
  final int? hardScheduledDesiredCount;
  final int? totalHardDesiredCount;

  int get unmetDesiredCount =>
      (totalDesiredCount - scheduledDesiredCount).clamp(0, totalDesiredCount);
  bool get fulfillsAll => unmetDesiredCount == 0;
}

class PlanningScenarioSet {
  const PlanningScenarioSet({
    required this.scenarios,
    required this.costComparisonReady,
  });

  final List<PlanningScenario> scenarios;
  final bool costComparisonReady;
}
