import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'master_data_validator.dart';

class MasterDataLoader {
  const MasterDataLoader({this.validator = const MasterDataValidator()});

  static const String manifestPath = 'assets/master/master_manifest.json';

  final MasterDataValidator validator;

  Future<void> importAll(DatabaseExecutor database) async {
    final result = await validator.validate(manifestPath: manifestPath);

    await _importParks(database, result.parkRows);

    await _importAreas(database, result.areaRows);

    for (final entry in result.facilityRowsByFile.entries) {
      await _importFacilities(database, entry.value);
    }
  }

  Future<void> _importParks(
    DatabaseExecutor database,
    List<Map<String, dynamic>> rows,
  ) async {
    for (final row in rows) {
      await database.insert('parks', {
        'id': row['id'],
        'resort_id': row['resortId'],
        'name': row['name'],
        'open_hour': row['defaultOpenHour'],
        'open_minute': row['defaultOpenMinute'],
        'close_hour': row['defaultCloseHour'],
        'close_minute': row['defaultCloseMinute'],
        'status': row['status'],
        'country': row['country'] ?? 'Japan',
        'timezone': row['timezone'] ?? 'Asia/Tokyo',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _importAreas(
    DatabaseExecutor database,
    List<Map<String, dynamic>> rows,
  ) async {
    for (final row in rows) {
      await database.insert('areas', {
        'id': row['id'],
        'park_id': row['parkId'],
        'name': row['name'],
        'latitude': row['latitude'] ?? 0,
        'longitude': row['longitude'] ?? 0,
        'display_order': row['displayOrder'] ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _importFacilities(
    DatabaseExecutor database,
    List<Map<String, dynamic>> rows,
  ) async {
    for (final row in rows) {
      await database.insert(
        'facilities',
        _facilityRowToDatabaseMap(row),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Map<String, Object?> _facilityRowToDatabaseMap(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'park_id': row['parkId'],
      'area_id': row['areaId'],
      'name': row['name'],
      'category': row['category'],
      'latitude': row['latitude'] ?? 0,
      'longitude': row['longitude'] ?? 0,
      'open_hour': row['openHour'],
      'open_minute': row['openMinute'],
      'close_hour': row['closeHour'],
      'close_minute': row['closeMinute'],
      'priority': row['priority'] ?? 'medium',
      'status': row['status'] ?? 'open',
      'description': row['description'],
      'reservation_type': row['reservationType'],
      'reservation_time': row['reservationTime'],
      'wait_minutes': row['waitMinutes'],
      'wait_updated_at': row['waitUpdatedAt'],
      'duration_minutes': row['durationMinutes'] ?? 60,
      'is_indoor': _boolToInteger(row['isIndoor']),
      'supports_dpa': _boolToInteger(row['supportsDpa']),
      'supports_priority_pass': _boolToInteger(row['supportsPriorityPass']),
      'supports_standby_pass': _boolToInteger(row['supportsStandbyPass']),
      'supports_single_rider': _boolToInteger(row['supportsSingleRider']),
      'requires_entry_request': _boolToInteger(row['requiresEntryRequest']),
      'requires_reservation': _boolToInteger(row['requiresReservation']),
      'is_seasonal': _boolToInteger(row['isSeasonal']),
      'is_operating': _boolToInteger(row['isOperating'], defaultValue: true),
      'min_height': row['minHeight'],
      'target_age': row['targetAge'],
      'display_order': row['displayOrder'] ?? 0,
      'ride_type': row['rideType'],
      'thrill_level': row['thrillLevel'],
      'is_water_ride': _boolToInteger(row['isWaterRide']),
      'is_dark_ride': _boolToInteger(row['isDarkRide']),
      'is_table_service': _boolToInteger(row['isTableService']),
      'supports_mobile_order': _boolToInteger(row['supportsMobileOrder']),
      'supports_priority_seating': _boolToInteger(
        row['supportsPrioritySeating'],
      ),
      'reservation_required': _boolToInteger(row['reservationRequired']),
      'shop_type': row['shopType'] ?? 'none',
      'restaurant_type': row['restaurantType'] ?? 'none',
      'representative_menu': row['representativeMenu'],
      'popcorn_flavor': row['popcornFlavor'],
      'menu_note': row['menuNote'],
      'is_show_restaurant': _boolToInteger(row['isShowRestaurant']),
      'show_name': row['showName'],
      'official_url': row['officialUrl'],
      'menu_url': row['menuUrl'],
    };
  }

  int _boolToInteger(Object? value, {bool defaultValue = false}) {
    if (value is bool) {
      return value ? 1 : 0;
    }

    if (value is num) {
      return value == 0 ? 0 : 1;
    }

    return defaultValue ? 1 : 0;
  }
}
