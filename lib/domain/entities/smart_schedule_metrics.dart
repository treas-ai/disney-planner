class SmartScheduleMetrics {
  const SmartScheduleMetrics({
    required this.areaTransitions,
    required this.predictedWaitMinutes,
    required this.highPriorityEarlyCount,
    required this.outdoorItemsInRain,
    required this.eventAffectedItems,
    required this.longWalkingStreaks,
    required this.walkingMinutes,
    required this.longDistanceMoves,
    required this.longDistanceBacktracks,
  });

  final int areaTransitions;
  final int predictedWaitMinutes;
  final int highPriorityEarlyCount;
  final int outdoorItemsInRain;
  final int eventAffectedItems;
  final int longWalkingStreaks;
  final int walkingMinutes;
  final int longDistanceMoves;
  final int longDistanceBacktracks;
}
