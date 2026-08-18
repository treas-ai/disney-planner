import '../enums/dining_location_type.dart';
import '../enums/facility_category.dart';
import '../enums/meal_period.dart';
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
    this.operatingHoursByDate = const <String, List<OperatingHours>>{},
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
    this.diningLocationType = DiningLocationType.inPark,
    this.mealPeriods = const <MealPeriod>{},
    this.requiresParkExit = false,
    this.requiresHotelStay = false,
    this.hotelId,
    this.outboundTravelMinutes = 0,
    this.returnTravelMinutes = 0,
  });

  final String id;
  final String parkId;
  final String areaId;
  final String name;
  final FacilityCategory category;
  final Coordinate coordinate;

  final OperatingHours? operatingHours;

  /// 公式サイト等から確認した日付別の運営時間。複数営業枠にも対応する。
  final Map<String, List<OperatingHours>> operatingHoursByDate;
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

  /// 食事場所の種別。ホテルレストランはパーク内施設と区別する。
  final DiningLocationType diningLocationType;

  /// 提供対象となる食事時間帯。
  final Set<MealPeriod> mealPeriods;

  /// 利用時にパーク退出が必要か。
  final bool requiresParkExit;

  /// 利用対象がホテル宿泊者に限定されるか。
  final bool requiresHotelStay;

  /// ホテルを識別するID。
  final String? hotelId;

  /// パークからレストランまでの見込み移動時間。
  final int outboundTravelMinutes;

  /// レストランからパークへ戻る見込み移動時間。
  final int returnTravelMinutes;

  bool get isHotelRestaurant {
    return diningLocationType == DiningLocationType.disneyHotel;
  }

  int get totalPlannedDurationMinutes {
    return durationMinutes + outboundTravelMinutes + returnTravelMinutes;
  }

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

    final target = _dateOnly(targetDateTime);

    switch (operatingStatus) {
      case FacilityOperatingStatus.operating:
      case FacilityOperatingStatus.scheduledClosure:
        return !_isInsideClosurePeriod(target);

      case FacilityOperatingStatus.temporarilyClosed:
      case FacilityOperatingStatus.seasonalClosed:
      case FacilityOperatingStatus.longTermClosed:
        if (closureStartDate != null || closureEndDate != null) {
          return !_isInsideClosurePeriod(target);
        }
        return false;

      case FacilityOperatingStatus.permanentlyClosed:
        return false;
    }
  }

  /// 指定日の公式確認済み運営時間を返す。
  /// 日付別データがない場合は従来の単一営業時間をフォールバックとして返す。
  List<OperatingHours> operatingWindowsFor(DateTime targetDate) {
    final key = _dateKey(targetDate);
    final daily = operatingHoursByDate[key];

    if (daily != null) {
      return List<OperatingHours>.unmodifiable(daily);
    }

    final fallback = operatingHours;
    if (fallback == null) {
      return const <OperatingHours>[];
    }

    return <OperatingHours>[
      OperatingHours(
        open: DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          fallback.open.hour,
          fallback.open.minute,
        ),
        close: DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          fallback.close.hour,
          fallback.close.minute,
        ),
      ),
    ];
  }

  bool hasVerifiedOperatingHoursFor(DateTime targetDate) {
    return operatingHoursByDate.containsKey(_dateKey(targetDate)) ||
        operatingHours != null;
  }

  bool _isInsideClosurePeriod(DateTime target) {
    final start = closureStartDate == null ? null : _dateOnly(closureStartDate!);
    final end = closureEndDate == null ? null : _dateOnly(closureEndDate!);

    if (start == null && end == null) {
      return false;
    }

    if (start != null && target.isBefore(start)) {
      return false;
    }

    if (end != null && target.isAfter(end)) {
      return false;
    }

    return true;
  }

  String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
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
