import '../enums/facility_category.dart';
import '../enums/park_status.dart';
import '../enums/priority_level.dart';
import '../value_objects/coordinate.dart';
import '../value_objects/operating_hours.dart';
import '../value_objects/reservation.dart';
import '../value_objects/wait_time.dart';

class Facility {
  const Facility({
    required this.id,
    required this.parkId,
    required this.areaId,
    required this.name,
    required this.category,
    required this.coordinate,
    this.operatingHours,
    this.waitTime,
    this.reservation,
    this.priority = PriorityLevel.medium,
    this.status = ParkStatus.open,
    this.description,
  });

  final String id;
  final String parkId;
  final String areaId;
  final String name;
  final FacilityCategory category;
  final Coordinate coordinate;

  final OperatingHours? operatingHours;
  final WaitTime? waitTime;
  final Reservation? reservation;

  final PriorityLevel priority;
  final ParkStatus status;
  final String? description;

  bool get isOpen => status == ParkStatus.open;
}
