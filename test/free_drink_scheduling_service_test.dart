import 'package:disney_planner/domain/entities/free_drink_pickup_profile.dart';
import 'package:disney_planner/domain/enums/free_drink_fulfillment_type.dart';
import 'package:disney_planner/domain/services/free_drink_scheduling_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = FreeDrinkSchedulingService();

  test('pickup during travel uses only rounded pickup block', () {
    const profile = FreeDrinkPickupProfile(
      itemId: 'drink',
      facilityId: 'restaurant',
      fulfillmentType: FreeDrinkFulfillmentType.pickup,
      orderMinutes: 0,
      pickupMinutes: 3,
      consumeMinutes: 7,
      requiresSeat: false,
      canInsertDuringTravel: true,
    );

    expect(service.displayPickupMinutes(profile), 5);
    expect(service.displayConsumeMinutes(profile), 10);
    expect(service.scheduleBlockMinutes(profile), 5);
  });
}
