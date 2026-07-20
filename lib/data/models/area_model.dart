import '../../domain/entities/area.dart';
import '../../domain/value_objects/coordinate.dart';

class AreaModel {
  const AreaModel._();

  static Area fromMap(Map<String, Object?> map) {
    return Area(
      id: map['id'] as String? ?? '',
      parkId: map['park_id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      coordinate: Coordinate(
        latitude: _readDouble(map['latitude']),
        longitude: _readDouble(map['longitude']),
      ),
    );
  }

  static Map<String, Object?> toMap(Area area) {
    return {
      'id': area.id,
      'park_id': area.parkId,
      'name': area.name,
      'latitude': area.coordinate.latitude,
      'longitude': area.coordinate.longitude,
    };
  }

  static double _readDouble(Object? value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return 0;
  }
}
