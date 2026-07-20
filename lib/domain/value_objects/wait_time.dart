class WaitTime {
  const WaitTime({required this.minutes, required this.updatedAt});

  final int minutes;
  final DateTime updatedAt;

  bool get isAvailable => minutes >= 0;
}
