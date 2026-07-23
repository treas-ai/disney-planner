import '../../../../domain/enums/restaurant_type.dart';
import '../../../../domain/enums/shop_type.dart';

class FacilityMasterTemplate {
  const FacilityMasterTemplate({
    required this.id,
    required this.parkId,
    required this.areaId,
    required this.name,
    required this.category,
    required this.displayOrder,
    this.latitude = 0,
    this.longitude = 0,
    this.priority = 'medium',
    this.status = 'open',
    this.description,
    this.durationMinutes = 60,
    this.openHour,
    this.openMinute,
    this.closeHour,
    this.closeMinute,
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
    this.reservationType,
    this.reservationTime,
    this.waitMinutes,
    this.waitUpdatedAt,
    this.shopType = ShopType.none,
    this.restaurantType = RestaurantType.none,
  });

  final String id;
  final String parkId;
  final String areaId;
  final String name;
  final String category;

  final double latitude;
  final double longitude;

  final String priority;
  final String status;
  final String? description;

  final int durationMinutes;
  final int displayOrder;

  final int? openHour;
  final int? openMinute;
  final int? closeHour;
  final int? closeMinute;

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

  final String? reservationType;
  final String? reservationTime;

  final int? waitMinutes;
  final String? waitUpdatedAt;

  final ShopType shopType;
  final RestaurantType restaurantType;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parkId': parkId,
      'areaId': areaId,
      'name': name,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'priority': priority,
      'status': status,
      'description': description,
      'durationMinutes': durationMinutes,
      'openHour': openHour,
      'openMinute': openMinute,
      'closeHour': closeHour,
      'closeMinute': closeMinute,
      'isIndoor': isIndoor,
      'supportsDpa': supportsDpa,
      'supportsPriorityPass': supportsPriorityPass,
      'supportsStandbyPass': supportsStandbyPass,
      'supportsSingleRider': supportsSingleRider,
      'requiresEntryRequest': requiresEntryRequest,
      'requiresReservation': requiresReservation,
      'isSeasonal': isSeasonal,
      'isOperating': isOperating,
      'minHeight': minHeight,
      'targetAge': targetAge,
      'displayOrder': displayOrder,
      'rideType': rideType,
      'thrillLevel': thrillLevel,
      'isWaterRide': isWaterRide,
      'isDarkRide': isDarkRide,
      'isTableService': isTableService,
      'supportsMobileOrder': supportsMobileOrder,
      'supportsPrioritySeating': supportsPrioritySeating,
      'reservationRequired': reservationRequired,
      'reservationType': reservationType,
      'reservationTime': reservationTime,
      'waitMinutes': waitMinutes,
      'waitUpdatedAt': waitUpdatedAt,
      'shopType': shopType.name,
      'restaurantType': restaurantType.name,
    };
  }

  FacilityMasterTemplate copyWith({
    String? id,
    String? parkId,
    String? areaId,
    String? name,
    String? category,
    double? latitude,
    double? longitude,
    String? priority,
    String? status,
    String? description,
    int? durationMinutes,
    int? displayOrder,
    int? openHour,
    int? openMinute,
    int? closeHour,
    int? closeMinute,
    bool? isIndoor,
    bool? supportsDpa,
    bool? supportsPriorityPass,
    bool? supportsStandbyPass,
    bool? supportsSingleRider,
    bool? requiresEntryRequest,
    bool? requiresReservation,
    bool? isSeasonal,
    bool? isOperating,
    double? minHeight,
    String? targetAge,
    String? rideType,
    int? thrillLevel,
    bool? isWaterRide,
    bool? isDarkRide,
    bool? isTableService,
    bool? supportsMobileOrder,
    bool? supportsPrioritySeating,
    bool? reservationRequired,
    String? reservationType,
    String? reservationTime,
    int? waitMinutes,
    String? waitUpdatedAt,
    ShopType? shopType,
    RestaurantType? restaurantType,
  }) {
    return FacilityMasterTemplate(
      id: id ?? this.id,
      parkId: parkId ?? this.parkId,
      areaId: areaId ?? this.areaId,
      name: name ?? this.name,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      description: description ?? this.description,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      displayOrder: displayOrder ?? this.displayOrder,
      openHour: openHour ?? this.openHour,
      openMinute: openMinute ?? this.openMinute,
      closeHour: closeHour ?? this.closeHour,
      closeMinute: closeMinute ?? this.closeMinute,
      isIndoor: isIndoor ?? this.isIndoor,
      supportsDpa: supportsDpa ?? this.supportsDpa,
      supportsPriorityPass: supportsPriorityPass ?? this.supportsPriorityPass,
      supportsStandbyPass: supportsStandbyPass ?? this.supportsStandbyPass,
      supportsSingleRider: supportsSingleRider ?? this.supportsSingleRider,
      requiresEntryRequest: requiresEntryRequest ?? this.requiresEntryRequest,
      requiresReservation: requiresReservation ?? this.requiresReservation,
      isSeasonal: isSeasonal ?? this.isSeasonal,
      isOperating: isOperating ?? this.isOperating,
      minHeight: minHeight ?? this.minHeight,
      targetAge: targetAge ?? this.targetAge,
      rideType: rideType ?? this.rideType,
      thrillLevel: thrillLevel ?? this.thrillLevel,
      isWaterRide: isWaterRide ?? this.isWaterRide,
      isDarkRide: isDarkRide ?? this.isDarkRide,
      isTableService: isTableService ?? this.isTableService,
      supportsMobileOrder: supportsMobileOrder ?? this.supportsMobileOrder,
      supportsPrioritySeating:
          supportsPrioritySeating ?? this.supportsPrioritySeating,
      reservationRequired: reservationRequired ?? this.reservationRequired,
      reservationType: reservationType ?? this.reservationType,
      reservationTime: reservationTime ?? this.reservationTime,
      waitMinutes: waitMinutes ?? this.waitMinutes,
      waitUpdatedAt: waitUpdatedAt ?? this.waitUpdatedAt,
      shopType: shopType ?? this.shopType,
      restaurantType: restaurantType ?? this.restaurantType,
    );
  }
}
