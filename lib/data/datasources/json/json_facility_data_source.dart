import '../../../domain/entities/facility.dart';
import '../../../domain/enums/facility_category.dart';
import '../../local/master_data/master_data_validator.dart';
import '../../models/facility_model.dart';
import '../facility_data_source.dart';

class JsonFacilityDataSource implements FacilityDataSource {
  const JsonFacilityDataSource({this.validator = const MasterDataValidator()});

  static const String _manifestPath = 'assets/master/master_manifest.json';

  static const String _serviceCategoryName = 'service';

  final MasterDataValidator validator;

  static Future<List<Facility>>? _cachedFacilities;

  @override
  Future<List<Facility>> getFacilities() async {
    final facilities = await _loadFacilities();

    return List<Facility>.unmodifiable(
      facilities.where(
        (facility) => facility.category.name != _serviceCategoryName,
      ),
    );
  }

  @override
  Future<List<Facility>> getFacilitiesByParkId(String parkId) async {
    final facilities = await _loadFacilities();

    final result = facilities
        .where(
          (facility) =>
              facility.parkId == parkId &&
              facility.category.name != _serviceCategoryName,
        )
        .toList(growable: false);

    result.sort(_compareByAreaAndOrder);

    return List<Facility>.unmodifiable(result);
  }

  @override
  Future<List<Facility>> getFacilitiesByAreaId(String areaId) async {
    final facilities = await _loadFacilities();

    final result = facilities
        .where(
          (facility) =>
              facility.areaId == areaId &&
              facility.category.name != _serviceCategoryName,
        )
        .toList(growable: false);

    result.sort(_compareByOrderAndName);

    return List<Facility>.unmodifiable(result);
  }

  @override
  Future<List<Facility>> getFacilitiesByCategory(
    FacilityCategory category,
  ) async {
    final facilities = await _loadFacilities();

    final result = facilities
        .where(
          (facility) =>
              facility.category == category &&
              facility.category.name != _serviceCategoryName,
        )
        .toList(growable: false);

    result.sort(_compareByParkAreaAndOrder);

    return List<Facility>.unmodifiable(result);
  }

  @override
  Future<Facility?> getFacilityById(String facilityId) async {
    final facilities = await _loadFacilities();

    for (final facility in facilities) {
      if (facility.id == facilityId &&
          facility.category.name != _serviceCategoryName) {
        return facility;
      }
    }

    return null;
  }

  Future<List<Facility>> _loadFacilities() {
    return _cachedFacilities ??= _createFacilities();
  }

  Future<List<Facility>> _createFacilities() async {
    final validationResult = await validator.validate(
      manifestPath: _manifestPath,
    );

    final facilities = <Facility>[];

    for (final entry in validationResult.facilityRowsByFile.entries) {
      for (final row in entry.value) {
        facilities.add(_createFacility(row));
      }
    }

    facilities.sort(_compareByParkAreaAndOrder);

    return List<Facility>.unmodifiable(facilities);
  }

  Facility _createFacility(Map<String, dynamic> row) {
    final databaseMap = <String, Object?>{
      'id': row['id'],
      'park_id': row['parkId'],
      'area_id': row['areaId'],
      'name': row['name'],
      'category': row['category'],
      'latitude': row['latitude'],
      'longitude': row['longitude'],
      'open_hour': row['openHour'],
      'open_minute': row['openMinute'],
      'close_hour': row['closeHour'],
      'close_minute': row['closeMinute'],
      'priority': row['priority'],
      'status': row['status'],
      'description': row['description'],
      'reservation_type': row['reservationType'],
      'reservation_time': row['reservationTime'],
      'wait_minutes': row['waitMinutes'],
      'wait_updated_at': row['waitUpdatedAt'],
      'duration_minutes': row['durationMinutes'],
      'display_order': row['displayOrder'],
      'is_indoor': row['isIndoor'],
      'supports_dpa': row['supportsDpa'],
      'supports_priority_pass': row['supportsPriorityPass'],
      'supports_standby_pass': row['supportsStandbyPass'],
      'supports_single_rider': row['supportsSingleRider'],
      'requires_entry_request': row['requiresEntryRequest'],
      'requires_reservation': row['requiresReservation'],
      'is_seasonal': row['isSeasonal'],
      'is_operating': row['isOperating'],
      'min_height': row['minHeight'],
      'target_age': row['targetAge'],
      'ride_type': row['rideType'],
      'thrill_level': row['thrillLevel'],
      'is_water_ride': row['isWaterRide'],
      'is_dark_ride': row['isDarkRide'],
      'is_table_service': row['isTableService'],
      'supports_mobile_order': row['supportsMobileOrder'],
      'supports_priority_seating': row['supportsPrioritySeating'],
      'reservation_required': row['reservationRequired'],
      'shop_type': row['shopType'] ?? 'none',
      'restaurant_type': row['restaurantType'] ?? 'none',
      'representative_menu': row['representativeMenu'],
      'popcorn_flavor': row['popcornFlavor'],
      'menu_note': row['menuNote'],
      'is_show_restaurant': row['isShowRestaurant'],
      'show_name': row['showName'],
      'official_url': row['officialUrl'],
      'menu_url': row['menuUrl'],
    };

    return FacilityModel.fromMap(databaseMap);
  }

  static int _compareByParkAreaAndOrder(Facility left, Facility right) {
    final parkComparison = left.parkId.compareTo(right.parkId);

    if (parkComparison != 0) {
      return parkComparison;
    }

    final areaComparison = left.areaId.compareTo(right.areaId);

    if (areaComparison != 0) {
      return areaComparison;
    }

    return _compareByOrderAndName(left, right);
  }

  static int _compareByAreaAndOrder(Facility left, Facility right) {
    final areaComparison = left.areaId.compareTo(right.areaId);

    if (areaComparison != 0) {
      return areaComparison;
    }

    return _compareByOrderAndName(left, right);
  }

  static int _compareByOrderAndName(Facility left, Facility right) {
    final orderComparison = left.displayOrder.compareTo(right.displayOrder);

    if (orderComparison != 0) {
      return orderComparison;
    }

    return left.name.compareTo(right.name);
  }

  static void clearCache() {
    _cachedFacilities = null;
  }
}
