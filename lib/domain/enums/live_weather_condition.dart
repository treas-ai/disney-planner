enum LiveWeatherCondition {
  sunny,
  cloudy,
  rain,
  heavyRain,
  windy,
  unknown;

  String get label => switch (this) {
    LiveWeatherCondition.sunny => '晴れ',
    LiveWeatherCondition.cloudy => 'くもり',
    LiveWeatherCondition.rain => '雨',
    LiveWeatherCondition.heavyRain => '強い雨',
    LiveWeatherCondition.windy => '強風',
    LiveWeatherCondition.unknown => '情報なし',
  };
}
