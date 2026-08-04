import '../enums/live_operation_availability.dart';

class AttractionOperation {
  const AttractionOperation({
    required this.parkId,
    required this.facilityId,
    required this.availability,
    required this.updatedAt,
    this.standbyMinutes,
    this.dpaAvailable,
    this.priorityPassAvailable,
    this.singleRiderAvailable,
    this.note,
  });

  final String parkId;
  final String facilityId;
  final LiveOperationAvailability availability;
  final DateTime updatedAt;
  final int? standbyMinutes;
  final bool? dpaAvailable;
  final bool? priorityPassAvailable;
  final bool? singleRiderAvailable;
  final String? note;
}
