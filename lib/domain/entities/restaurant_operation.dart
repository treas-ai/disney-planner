import '../enums/live_operation_availability.dart';

class RestaurantOperation {
  const RestaurantOperation({
    required this.parkId,
    required this.facilityId,
    required this.availability,
    required this.updatedAt,
    this.mobileOrderAvailable,
    this.acceptingOrders,
    this.seatAvailabilityLabel,
    this.note,
  });

  final String parkId;
  final String facilityId;
  final LiveOperationAvailability availability;
  final DateTime updatedAt;
  final bool? mobileOrderAvailable;
  final bool? acceptingOrders;
  final String? seatAvailabilityLabel;
  final String? note;
}
