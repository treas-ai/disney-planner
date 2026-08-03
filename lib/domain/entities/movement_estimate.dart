class MovementEstimate {
  const MovementEstimate({
    required this.fromAreaId,
    required this.toAreaId,
    required this.minutes,
    required this.arrivalAt,
    required this.isFallback,
    required this.pathAreaIds,
  });

  final String fromAreaId;
  final String toAreaId;
  final int minutes;
  final DateTime arrivalAt;
  final bool isFallback;
  final List<String> pathAreaIds;
}
