class SmartScheduleMetrics {
  const SmartScheduleMetrics({
    required this.areaTransitions,
    required this.predictedWaitMinutes,
    required this.highPriorityEarlyCount,
    required this.outdoorItemsInRain,
    required this.eventAffectedItems,
    required this.longWalkingStreaks,
  });

  final int areaTransitions;
  final int predictedWaitMinutes;
  final int highPriorityEarlyCount;
  final int outdoorItemsInRain;
  final int eventAffectedItems;
  final int longWalkingStreaks;
}
