import '../enums/live_operation_availability.dart';

class ManualWaitTimeEntry {
  const ManualWaitTimeEntry({
    required this.parkId,
    required this.facilityId,
    required this.availability,
    required this.updatedAt,
    this.standbyMinutes,
    this.previousStandbyMinutes,
  });

  final String parkId;
  final String facilityId;
  final LiveOperationAvailability availability;
  final DateTime updatedAt;
  final int? standbyMinutes;
  final int? previousStandbyMinutes;

  bool get isStale =>
      DateTime.now().difference(updatedAt) > const Duration(minutes: 30);

  int? get differenceMinutes {
    final current = standbyMinutes;
    final previous = previousStandbyMinutes;
    if (current == null || previous == null) {
      return null;
    }
    return current - previous;
  }

  Map<String, Object?> toJson() {
    return {
      'parkId': parkId,
      'facilityId': facilityId,
      'availability': availability.name,
      'updatedAt': updatedAt.toIso8601String(),
      'standbyMinutes': standbyMinutes,
      'previousStandbyMinutes': previousStandbyMinutes,
    };
  }

  factory ManualWaitTimeEntry.fromJson(Map<String, Object?> json) {
    return ManualWaitTimeEntry(
      parkId: json['parkId'] as String,
      facilityId: json['facilityId'] as String,
      availability: LiveOperationAvailability.values.firstWhere(
        (value) => value.name == json['availability'],
        orElse: () => LiveOperationAvailability.unknown,
      ),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      standbyMinutes: json['standbyMinutes'] as int?,
      previousStandbyMinutes: json['previousStandbyMinutes'] as int?,
    );
  }
}
