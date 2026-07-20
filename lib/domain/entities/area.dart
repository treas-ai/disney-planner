import '../value_objects/coordinate.dart';

class Area {
  const Area({
    required this.id,
    required this.parkId,
    required this.name,
    required this.coordinate,
  });

  final String id;
  final String parkId;
  final String name;
  final Coordinate coordinate;
}
