class ParkOperation {
  const ParkOperation({
    required this.parkId,
    required this.openTime,
    required this.closeTime,
    required this.updatedAt,
    this.happyEntryAvailable = false,
    this.isOpen = true,
    this.note,
  });

  final String parkId;
  final String openTime;
  final String closeTime;
  final DateTime updatedAt;
  final bool happyEntryAvailable;
  final bool isOpen;
  final String? note;

  String get operatingHoursLabel => '$openTime〜$closeTime';
}
