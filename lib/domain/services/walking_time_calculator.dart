import '../value_objects/walking_route.dart';

class WalkingTimeCalculator {
  const WalkingTimeCalculator();

  int calculateMinutes({
    required String fromAreaId,
    required String toAreaId,
    required List<WalkingRoute> routes,
  }) {
    if (fromAreaId == toAreaId) {
      return 0;
    }

    for (final route in routes) {
      final isForwardRoute =
          route.fromAreaId == fromAreaId && route.toAreaId == toAreaId;

      final isReverseRoute =
          route.fromAreaId == toAreaId && route.toAreaId == fromAreaId;

      if (isForwardRoute || isReverseRoute) {
        return route.minutes;
      }
    }

    return 10;
  }
}