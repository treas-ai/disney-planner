import '../enums/live_crowd_level.dart';

class CrowdSnapshot {
  const CrowdSnapshot({
    required this.parkId,
    required this.parkLevel,
    required this.updatedAt,
    this.areaLevels = const {},
    this.peakTimeLabel,
  });

  final String parkId;
  final LiveCrowdLevel parkLevel;
  final DateTime updatedAt;
  final Map<String, LiveCrowdLevel> areaLevels;
  final String? peakTimeLabel;
}
