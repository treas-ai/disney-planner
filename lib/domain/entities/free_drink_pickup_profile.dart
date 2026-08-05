import '../enums/free_drink_fulfillment_type.dart';

class FreeDrinkPickupProfile {
  const FreeDrinkPickupProfile({
    required this.itemId,
    required this.facilityId,
    required this.fulfillmentType,
    required this.orderMinutes,
    required this.pickupMinutes,
    required this.consumeMinutes,
    required this.requiresSeat,
    required this.canInsertDuringTravel,
  }) : assert(orderMinutes >= 0),
       assert(pickupMinutes >= 0),
       assert(consumeMinutes >= 0);

  factory FreeDrinkPickupProfile.fromJson(Map<String, dynamic> json) {
    return FreeDrinkPickupProfile(
      itemId: json['itemId'] as String? ?? '',
      facilityId: json['facilityId'] as String? ?? '',
      fulfillmentType: FreeDrinkFulfillmentType.fromName(
        json['fulfillmentType'] as String?,
      ),
      orderMinutes: json['orderMinutes'] as int? ?? 0,
      pickupMinutes: json['pickupMinutes'] as int? ?? 5,
      consumeMinutes: json['consumeMinutes'] as int? ?? 10,
      requiresSeat: json['requiresSeat'] as bool? ?? false,
      canInsertDuringTravel: json['canInsertDuringTravel'] as bool? ?? true,
    );
  }

  final String itemId;
  final String facilityId;
  final FreeDrinkFulfillmentType fulfillmentType;
  final int orderMinutes;
  final int pickupMinutes;
  final int consumeMinutes;
  final bool requiresSeat;
  final bool canInsertDuringTravel;

  int get totalInternalMinutes => orderMinutes + pickupMinutes + consumeMinutes;

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'facilityId': facilityId,
      'fulfillmentType': fulfillmentType.name,
      'orderMinutes': orderMinutes,
      'pickupMinutes': pickupMinutes,
      'consumeMinutes': consumeMinutes,
      'requiresSeat': requiresSeat,
      'canInsertDuringTravel': canInsertDuringTravel,
    };
  }
}
