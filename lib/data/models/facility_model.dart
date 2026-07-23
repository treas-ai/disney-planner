import '../../domain/entities/facility.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/enums/park_status.dart';
import '../../domain/enums/priority_level.dart';
import '../../domain/enums/reservation_type.dart';
import '../../domain/enums/restaurant_type.dart';
import '../../domain/enums/shop_type.dart';
import '../../domain/value_objects/coordinate.dart';
import '../../domain/value_objects/operating_hours.dart';
import '../../domain/value_objects/reservation.dart';
import '../../domain/value_objects/wait_time.dart';

class FacilityModel {
  const FacilityModel._();

  static Facility fromMap(Map<String, Object?> map, {DateTime? targetDate}) {
    final date = targetDate ?? DateTime.now();

    return Facility(
      id: _readString(map['id']),
      parkId: _readString(map['park_id']),
      areaId: _readString(map['area_id']),
      name: _readString(map['name']),
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
      description: _readNullableString(map['description']),
      durationMinutes: _readNullableInt(map['duration_minutes']) ?? 60,
      displayOrder: _readNullableInt(map['display_order']) ?? 0,
      isIndoor: _readBool(map['is_indoor']),
      supportsDpa: _readBool(map['supports_dpa']),
      supportsPriorityPass: _readBool(map['supports_priority_pass']),
      supportsStandbyPass: _readBool(map['supports_standby_pass']),
      supportsSingleRider: _readBool(map['supports_single_rider']),
      requiresEntryRequest: _readBool(map['requires_entry_request']),
      requiresReservation: _readBool(map['requires_reservation']),
      isSeasonal: _readBool(map['is_seasonal']),
      isOperating: _readBool(map['is_operating'], defaultValue: true),
      minHeight: _readNullableDouble(map['min_height']),
      targetAge: _readNullableString(map['target_age']),
      rideType: _readNullableString(map['ride_type']),
      thrillLevel: _readNullableInt(map['thrill_level']),
      isWaterRide: _readBool(map['is_water_ride']),
      isDarkRide: _readBool(map['is_dark_ride']),
      isTableService: _readBool(map['is_table_service']),
      supportsMobileOrder: _readBool(map['supports_mobile_order']),
      supportsPrioritySeating: _readBool(map['supports_priority_seating']),
      reservationRequired: _readBool(map['reservation_required']),
      shopType: _readShopType(map['shop_type']),
      restaurantType: _readRestaurantType(map['restaurant_type']),
      representativeMenu: _readNullableString(map['representative_menu']),
      popcornFlavor: _readNullableString(map['popcorn_flavor']),
      menuNote: _readNullableString(map['menu_note']),
      isShowRestaurant: _readBool(map['is_show_restaurant']),
      showName: _readNullableString(map['show_name']),
      officialUrl: _readNullableString(map['official_url']),
      menuUrl: _readNullableString(map['menu_url']),
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
      'duration_minutes': facility.durationMinutes,
      'display_order': facility.displayOrder,
      'is_indoor': facility.isIndoor ? 1 : 0,
      'supports_dpa': facility.supportsDpa ? 1 : 0,
      'supports_priority_pass': facility.supportsPriorityPass ? 1 : 0,
      'supports_standby_pass': facility.supportsStandbyPass ? 1 : 0,
      'supports_single_rider': facility.supportsSingleRider ? 1 : 0,
      'requires_entry_request': facility.requiresEntryRequest ? 1 : 0,
      'requires_reservation': facility.requiresReservation ? 1 : 0,
      'is_seasonal': facility.isSeasonal ? 1 : 0,
      'is_operating': facility.isOperating ? 1 : 0,
      'min_height': facility.minHeight,
      'target_age': facility.targetAge,
      'ride_type': facility.rideType,
      'thrill_level': facility.thrillLevel,
      'is_water_ride': facility.isWaterRide ? 1 : 0,
      'is_dark_ride': facility.isDarkRide ? 1 : 0,
      'is_table_service': facility.isTableService ? 1 : 0,
      'supports_mobile_order': facility.supportsMobileOrder ? 1 : 0,
      'supports_priority_seating': facility.supportsPrioritySeating ? 1 : 0,
      'reservation_required': facility.reservationRequired ? 1 : 0,
      'shop_type': facility.shopType.name,
      'restaurant_type': facility.restaurantType.name,
      'representative_menu': facility.representativeMenu,
      'popcorn_flavor': facility.popcornFlavor,
      'menu_note': facility.menuNote,
      'is_show_restaurant': facility.isShowRestaurant ? 1 : 0,
      'show_name': facility.showName,
      'official_url': facility.officialUrl,
      'menu_url': facility.menuUrl,
    };
  }

  static FacilityCategory _readFacilityCategory(Object? value) {
    final name = value as String?;

    return FacilityCategory.values.firstWhere(
      (category) => category.name == name,
      orElse: () => FacilityCategory.attraction,
    );
  }

  static PriorityLevel _readPriorityLevel(Object? value) {
    final name = value as String?;

    return PriorityLevel.values.firstWhere(
      (priority) => priority.name == name,
      orElse: () => PriorityLevel.medium,
    );
  }

  static ParkStatus _readParkStatus(Object? value) {
    final name = value as String?;

    return ParkStatus.values.firstWhere(
      (status) => status.name == name,
      orElse: () => ParkStatus.open,
    );
  }

  static ShopType _readShopType(Object? value) {
    final name = value as String?;

    return ShopType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => ShopType.none,
    );
  }

  static RestaurantType _readRestaurantType(Object? value) {
    final name = value as String?;

    return RestaurantType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => RestaurantType.none,
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
    final updatedAtText = _readNullableString(map['wait_updated_at']);

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
    final typeName = _readNullableString(map['reservation_type']);

    if (typeName == null) {
      return null;
    }

    final type = ReservationType.values.firstWhere(
      (reservationType) => reservationType.name == typeName,
      orElse: () => ReservationType.none,
    );

    final reservationTimeText = _readNullableString(map['reservation_time']);

    return Reservation(
      type: type,
      time: reservationTimeText == null
          ? null
          : DateTime.tryParse(reservationTimeText),
    );
  }

  static String _readString(Object? value) {
    return value is String ? value : '';
  }

  static String? _readNullableString(Object? value) {
    if (value is! String) {
      return null;
    }

    final trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
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
    if (value is num) {
      return value.toDouble();
    }

    return 0;
  }

  static double? _readNullableDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return null;
  }

  static bool _readBool(Object? value, {bool defaultValue = false}) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    return defaultValue;
  }
}
