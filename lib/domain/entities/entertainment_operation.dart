import '../enums/live_operation_availability.dart';

class EntertainmentOperation {
  const EntertainmentOperation({
    required this.parkId,
    required this.facilityId,
    required this.availability,
    required this.updatedAt,
    this.entryRequestAvailable,
    this.freeSeatingAvailable,
    this.queueOpen,
    this.nextPerformanceTime,
    this.note,
  });

  final String parkId;
  final String facilityId;
  final LiveOperationAvailability availability;
  final DateTime updatedAt;
  final bool? entryRequestAvailable;
  final bool? freeSeatingAvailable;
  final bool? queueOpen;
  final String? nextPerformanceTime;
  final String? note;
}
