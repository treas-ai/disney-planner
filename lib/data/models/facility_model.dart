import '../../domain/entities/facility.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/enums/park_status.dart';
import '../../domain/enums/priority_level.dart';
import '../../domain/enums/reservation_type.dart';
import '../../domain/value_objects/coordinate.dart';
import '../../domain/value_objects/operating_hours.dart';
import '../../domain/value_objects/reservation.dart';
import '../../domain/value_objects/wait_time.dart';

class FacilityModel {
  const FacilityModel._();

  static Facility fromMap(Map<String, Object?> map, {DateTime? targetDate}) {
    final date = targetDate ?? DateTime.now();

    return Facility(
      id: map['id'] as String? ?? '',
      parkId: map['park_id'] as String? ?? '',
      areaId: map['area_id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      category: _readFacilityCategory(map['category']),
      coordinate: Coordinate(
        latitude: _readDouble(map['latitude']),
        longitude: _readDouble(map['longitude']),
      ),
      operatingHours: _readOperatingHours(map, targetDate: date),
      waitTime: _readWaitTime(map),
      reservation: _readReservation(map),
      priority: _readPriorityLevel(map['priority']),
      status: _readParkStatus(map['status']),
      description: map['description'] as String?,
    );
  }

  static Map<String, Object?> toMap(Facility facility) {
    return {
      'id': facility.id,
      'park_id': facility.parkId,
      'area_id': facility.areaId,
      'name': facility.name,
      'category': facility.category.name,
      'latitude': facility.coordinate.latitude,
      'longitude': facility.coordinate.longitude,
      'open_hour': facility.operatingHours?.open.hour,
      'open_minute': facility.operatingHours?.open.minute,
      'close_hour': facility.operatingHours?.close.hour,
      'close_minute': facility.operatingHours?.close.minute,
      'priority': facility.priority.name,
      'status': facility.status.name,
      'description': facility.description,
      'reservation_type': facility.reservation?.type.name,
      'reservation_time': facility.reservation?.time?.toIso8601String(),
      'wait_minutes': facility.waitTime?.minutes,
      'wait_updated_at': facility.waitTime?.updatedAt.toIso8601String(),
    };
  }

  static FacilityCategory _readFacilityCategory(Object? value) {
    final categoryName = value as String?;

    return FacilityCategory.values.firstWhere(
      (category) => category.name == categoryName,
      orElse: () => FacilityCategory.attraction,
    );
  }

  static PriorityLevel _readPriorityLevel(Object? value) {
    final priorityName = value as String?;

    return PriorityLevel.values.firstWhere(
      (priority) => priority.name == priorityName,
      orElse: () => PriorityLevel.medium,
    );
  }

  static ParkStatus _readParkStatus(Object? value) {
    final statusName = value as String?;

    return ParkStatus.values.firstWhere(
      (status) => status.name == statusName,
      orElse: () => ParkStatus.open,
    );
  }

  static OperatingHours? _readOperatingHours(
    Map<String, Object?> map, {
    required DateTime targetDate,
  }) {
    final openHour = _readNullableInt(map['open_hour']);
    final openMinute = _readNullableInt(map['open_minute']);
    final closeHour = _readNullableInt(map['close_hour']);
    final closeMinute = _readNullableInt(map['close_minute']);

    if (openHour == null ||
        openMinute == null ||
        closeHour == null ||
        closeMinute == null) {
      return null;
    }

    return OperatingHours(
      open: DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        openHour,
        openMinute,
      ),
      close: DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        closeHour,
        closeMinute,
      ),
    );
  }

  static WaitTime? _readWaitTime(Map<String, Object?> map) {
    final minutes = _readNullableInt(map['wait_minutes']);
    final updatedAtText = map['wait_updated_at'] as String?;

    if (minutes == null || updatedAtText == null) {
      return null;
    }

    final updatedAt = DateTime.tryParse(updatedAtText);

    if (updatedAt == null) {
      return null;
    }

    return WaitTime(minutes: minutes, updatedAt: updatedAt);
  }

  static Reservation? _readReservation(Map<String, Object?> map) {
    final typeName = map['reservation_type'] as String?;

    if (typeName == null || typeName.isEmpty) {
      return null;
    }

    final type = ReservationType.values.firstWhere(
      (reservationType) => reservationType.name == typeName,
      orElse: () => ReservationType.none,
    );

    final reservationTimeText = map['reservation_time'] as String?;

    return Reservation(
      type: type,
      time: reservationTimeText == null
          ? null
          : DateTime.tryParse(reservationTimeText),
    );
  }

  static int? _readNullableInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return null;
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
