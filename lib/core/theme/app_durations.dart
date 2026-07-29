class AppDurations {
  const AppDurations._();

  static const Duration instant = Duration.zero;

  static const Duration veryFast = Duration(milliseconds: 120);

  static const Duration fast = Duration(milliseconds: 180);

  static const Duration normal = Duration(milliseconds: 240);

  static const Duration slow = Duration(milliseconds: 360);

  static const Duration verySlow = Duration(milliseconds: 500);
}
