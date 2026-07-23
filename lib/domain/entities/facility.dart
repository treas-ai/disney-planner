import '../enums/facility_category.dart';
import '../enums/park_status.dart';
import '../enums/priority_level.dart';
import '../enums/restaurant_type.dart';
import '../enums/shop_type.dart';
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
    this.durationMinutes = 60,
    this.displayOrder = 0,
    this.isIndoor = false,
    this.supportsDpa = false,
    this.supportsPriorityPass = false,
    this.supportsStandbyPass = false,
    this.supportsSingleRider = false,
    this.requiresEntryRequest = false,
    this.requiresReservation = false,
    this.isSeasonal = false,
    this.isOperating = true,
    this.minHeight,
    this.targetAge,
    this.rideType,
    this.thrillLevel,
    this.isWaterRide = false,
    this.isDarkRide = false,
    this.isTableService = false,
    this.supportsMobileOrder = false,
    this.supportsPrioritySeating = false,
    this.reservationRequired = false,
    this.shopType = ShopType.none,
    this.restaurantType = RestaurantType.none,
    this.representativeMenu,
    this.popcornFlavor,
    this.menuNote,
    this.isShowRestaurant = false,
    this.showName,
    this.officialUrl,
    this.menuUrl,
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

  final int durationMinutes;
  final int displayOrder;

  final bool isIndoor;
  final bool supportsDpa;
  final bool supportsPriorityPass;
  final bool supportsStandbyPass;
  final bool supportsSingleRider;
  final bool requiresEntryRequest;
  final bool requiresReservation;
  final bool isSeasonal;
  final bool isOperating;

  final double? minHeight;
  final String? targetAge;
  final String? rideType;
  final int? thrillLevel;

  final bool isWaterRide;
  final bool isDarkRide;

  final bool isTableService;
  final bool supportsMobileOrder;
  final bool supportsPrioritySeating;
  final bool reservationRequired;

  final ShopType shopType;
  final RestaurantType restaurantType;

  final String? representativeMenu;
  final String? popcornFlavor;
  final String? menuNote;

  final bool isShowRestaurant;
  final String? showName;

  final String? officialUrl;
  final String? menuUrl;

  bool get isOpen {
    return status == ParkStatus.open && isOperating;
  }

  bool get isRestaurant {
    return category == FacilityCategory.restaurant;
  }

  bool get isShop {
    return category == FacilityCategory.shop;
  }

  bool get isCapsuleToy {
    return isShop && shopType == ShopType.capsuleToy;
  }

  bool get isPopcornWagon {
    return isRestaurant &&
        restaurantType == RestaurantType.foodWagon &&
        (popcornFlavor?.trim().isNotEmpty ?? false);
  }

  bool get hasOfficialUrl {
    return _isValidWebUrl(officialUrl);
  }

  bool get hasMenuUrl {
    return _isValidWebUrl(menuUrl);
  }

  String? get primaryProductLabel {
    final flavor = popcornFlavor?.trim();

    if (flavor != null && flavor.isNotEmpty) {
      return flavor;
    }

    final menu = representativeMenu?.trim();

    if (menu != null && menu.isNotEmpty) {
      return menu;
    }

    return null;
  }

  bool _isValidWebUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(value.trim());

    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }
}
