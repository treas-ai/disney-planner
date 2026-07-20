import '../../domain/entities/park.dart';
import '../../domain/enums/park_status.dart';
import '../../domain/value_objects/operating_hours.dart';

class ParkModel {
  const ParkModel._();

  static Park fromMap(
    Map<String, Object?> map, {
    List<String> areaIds = const [],
    DateTime? targetDate,
  }) {
    final date = targetDate ?? DateTime.now();

    final openHour = _readInt(map['open_hour'], fallback: 9);
    final openMinute = _readInt(map['open_minute']);
    final closeHour = _readInt(map['close_hour'], fallback: 21);
    final closeMinute = _readInt(map['close_minute']);

    return Park(
      id: map['id'] as String? ?? '',
      resortId: map['resort_id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      areaIds: List.unmodifiable(areaIds),
      operatingHours: OperatingHours(
        open: DateTime(date.year, date.month, date.day, openHour, openMinute),
        close: DateTime(
          date.year,
          date.month,
          date.day,
          closeHour,
          closeMinute,
        ),
      ),
      status: _readParkStatus(map['status']),
    );
  }

  static Map<String, Object?> toMap(Park park) {
    return {
      'id': park.id,
      'resort_id': park.resortId,
      'name': park.name,
      'open_hour': park.operatingHours.open.hour,
      'open_minute': park.operatingHours.open.minute,
      'close_hour': park.operatingHours.close.hour,
      'close_minute': park.operatingHours.close.minute,
      'status': park.status.name,
    };
  }

  static ParkStatus _readParkStatus(Object? value) {
    final statusName = value as String?;

    return ParkStatus.values.firstWhere(
      (status) => status.name == statusName,
      orElse: () => ParkStatus.open,
    );
  }

  static int _readInt(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return fallback;
  }
}
