import '../enums/fatigue_level.dart';
import '../enums/live_weather_condition.dart';

class FatigueEstimationService {
  const FatigueEstimationService();

  FatigueLevel estimate({
    required Duration elapsedInPark,
    int walkingMinutes = 0,
    LiveWeatherCondition? weather,
    bool hasBaggage = false,
    int minutesSinceBreak = 0,
  }) {
    var points = 0;

    if (elapsedInPark.inHours >= 8) {
      points += 3;
    } else if (elapsedInPark.inHours >= 5) {
      points += 2;
    } else if (elapsedInPark.inHours >= 3) {
      points += 1;
    }

    if (walkingMinutes >= 180) {
      points += 2;
    } else if (walkingMinutes >= 90) {
      points += 1;
    }

    if (weather == LiveWeatherCondition.heavyRain) {
      points += 2;
    } else if (weather == LiveWeatherCondition.rain) {
      points += 1;
    }

    if (hasBaggage) points += 1;
    if (minutesSinceBreak >= 180) points += 1;

    if (points >= 5) return FatigueLevel.high;
    if (points >= 2) return FatigueLevel.medium;
    return FatigueLevel.low;
  }
}
