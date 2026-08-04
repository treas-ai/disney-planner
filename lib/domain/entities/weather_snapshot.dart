import '../enums/live_weather_condition.dart';

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.condition,
    required this.updatedAt,
    this.temperatureCelsius,
    this.precipitationMillimeters,
    this.windSpeedMetersPerSecond,
  });

  final LiveWeatherCondition condition;
  final DateTime updatedAt;
  final double? temperatureCelsius;
  final double? precipitationMillimeters;
  final double? windSpeedMetersPerSecond;
}
