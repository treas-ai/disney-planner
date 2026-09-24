class PlanCoverageScenario {
  const PlanCoverageScenario({
    required this.dpaCount,
    required this.scheduledFacilityIds,
    required this.scheduledDesiredCount,
    required this.selectedDpaFacilityIds,
    this.totalWaitMinutes,
    this.totalFreeMinutes,
    this.totalMovementMinutes,
    this.hardScheduledDesiredCount,
    this.totalHardDesiredCount,
  });

  final int dpaCount;
  final Set<String> scheduledFacilityIds;
  final int scheduledDesiredCount;
  final List<String> selectedDpaFacilityIds;
  final int? totalWaitMinutes;
  final int? totalFreeMinutes;
  final int? totalMovementMinutes;
  final int? hardScheduledDesiredCount;
  final int? totalHardDesiredCount;
}

class UnmetPlanFacilityAdvice {
  const UnmetPlanFacilityAdvice({
    required this.facilityId,
    required this.name,
    required this.supportsDpa,
    required this.reason,
    this.firstRescuedAtDpaCount,
  });

  final String facilityId;
  final String name;
  final bool supportsDpa;
  final String reason;
  final int? firstRescuedAtDpaCount;
}

class DpaAcquisitionAdvice {
  const DpaAcquisitionAdvice({
    required this.order,
    required this.facilityId,
    required this.name,
    required this.reason,
    this.estimatedSavedMinutes,
  });

  final int order;
  final String facilityId;
  final String name;
  final String reason;
  final int? estimatedSavedMinutes;
}

class PlanCoverageAdvice {
  const PlanCoverageAdvice({
    required this.totalDesiredCount,
    required this.currentScheduledCount,
    required this.unmetFacilities,
    required this.scenarios,
    required this.dpaAcquisitionOrder,
    required this.simulatedMaxDpaCount,
    this.minimumDpaCountForAll,
  });

  final int totalDesiredCount;
  final int currentScheduledCount;
  final List<UnmetPlanFacilityAdvice> unmetFacilities;
  final List<PlanCoverageScenario> scenarios;
  final List<DpaAcquisitionAdvice> dpaAcquisitionOrder;
  final int simulatedMaxDpaCount;
  final int? minimumDpaCountForAll;

  bool get allDesiredScheduled => currentScheduledCount >= totalDesiredCount;
}
