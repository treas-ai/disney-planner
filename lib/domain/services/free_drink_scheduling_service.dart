import '../entities/free_drink_pickup_profile.dart';
import 'time_rounding_service.dart';

class FreeDrinkSchedulingService {
  const FreeDrinkSchedulingService({
    this.timeRoundingService = const TimeRoundingService(),
  });

  final TimeRoundingService timeRoundingService;

  int displayPickupMinutes(FreeDrinkPickupProfile profile) {
    final internalMinutes = profile.orderMinutes + profile.pickupMinutes;
    return timeRoundingService.ceilMinutes(internalMinutes);
  }

  int displayConsumeMinutes(FreeDrinkPickupProfile profile) {
    return timeRoundingService.ceilMinutes(profile.consumeMinutes);
  }

  int scheduleBlockMinutes(FreeDrinkPickupProfile profile) {
    if (profile.canInsertDuringTravel && !profile.requiresSeat) {
      return displayPickupMinutes(profile);
    }
    return timeRoundingService.ceilMinutes(profile.totalInternalMinutes);
  }
}
