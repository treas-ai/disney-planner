class LearningDataSummary {
  const LearningDataSummary({
    required this.totalRecordCount,
    required this.trainingEligibleRecordCount,
    required this.waitTimeRecordCount,
    required this.movementRecordCount,
    required this.earliestRecordedAt,
    required this.latestRecordedAt,
  });

  final int totalRecordCount;
  final int trainingEligibleRecordCount;
  final int waitTimeRecordCount;
  final int movementRecordCount;
  final DateTime? earliestRecordedAt;
  final DateTime? latestRecordedAt;
}
