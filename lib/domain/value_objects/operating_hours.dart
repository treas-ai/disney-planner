class OperatingHours {
  const OperatingHours({
    required this.open,
    required this.close,
  });

  final DateTime open;
  final DateTime close;

  bool contains(DateTime time) {
    return time.isAfter(open) && time.isBefore(close);
  }
}