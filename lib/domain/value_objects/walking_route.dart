class WalkingRoute {
  const WalkingRoute({
    required this.fromAreaId,
    required this.toAreaId,
    required this.minutes,
  });

  final String fromAreaId;
  final String toAreaId;
  final int minutes;
}
