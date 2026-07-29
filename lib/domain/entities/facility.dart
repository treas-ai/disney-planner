import '../enums/facility_category.dart';
import '../enums/facility_operating_status.dart';
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
    this.operatingStatus = FacilityOperatingStatus.operating,
    this.closureStartDate,
    this.closureEndDate,
    this.operatingStatusNote,
    this.operatingStatusCheckedAt,
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

  /// 既存データとの互換性維持用。
  final bool isOperating;

  /// 施設固有の営業状態。
  final FacilityOperatingStatus operatingStatus;

  /// 休止開始日。
  final DateTime? closureStartDate;

  /// 休止終了日。再開日未定の場合はnull。
  final DateTime? closureEndDate;

  /// 再開時期未定など、営業状態に関する補足。
  final String? operatingStatusNote;

  /// 公式情報を最後に確認した日。
  final DateTime? operatingStatusCheckedAt;

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
    return canAddToPlanAt(DateTime.now());
  }

  bool get isCurrentlyClosed {
    return !isOpen;
  }

  bool get hasClosurePeriod {
    return closureStartDate != null || closureEndDate != null;
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

  bool canAddToPlanAt(DateTime targetDateTime) {
    if (!isOperating || status != ParkStatus.open) {
      return false;
    }

    switch (operatingStatus) {
      case FacilityOperatingStatus.operating:
        return true;

      case FacilityOperatingStatus.scheduledClosure:
        final startDate = closureStartDate;

        if (startDate == null) {
          return true;
        }

        return _dateOnly(targetDateTime).isBefore(_dateOnly(startDate));

      case FacilityOperatingStatus.temporarilyClosed:
      case FacilityOperatingStatus.seasonalClosed:
      case FacilityOperatingStatus.longTermClosed:
      case FacilityOperatingStatus.permanentlyClosed:
        return false;
    }
  }

  String get operatingStatusDisplayLabel {
    if (operatingStatus == FacilityOperatingStatus.scheduledClosure) {
      final startDate = closureStartDate;

      if (startDate != null) {
        return '${operatingStatus.label}（${_formatDate(startDate)}から）';
      }
    }

    return operatingStatus.label;
  }

  String? get closurePeriodLabel {
    final startDate = closureStartDate;
    final endDate = closureEndDate;

    if (startDate == null && endDate == null) {
      return null;
    }

    if (startDate != null && endDate != null) {
      return '${_formatDate(startDate)}～${_formatDate(endDate)}';
    }

    if (startDate != null) {
      return '${_formatDate(startDate)}から';
    }

    return '${_formatDate(endDate!)}まで';
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

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _formatDate(DateTime value) {
    return '${value.year}年'
        '${value.month}月'
        '${value.day}日';
  }
}
