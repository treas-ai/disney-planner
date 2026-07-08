import '../enums/park_status.dart';
import '../value_objects/operating_hours.dart';

class Park {
  const Park({
    required this.id,
    required this.resortId,
    required this.name,
    required this.areaIds,
    required this.operatingHours,
    this.status = ParkStatus.open,
  });

  final String id;
  final String resortId;
  final String name;
  final List<String> areaIds;
  final OperatingHours operatingHours;
  final ParkStatus status;
}