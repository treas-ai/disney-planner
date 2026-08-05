class TimeRoundingService {
  const TimeRoundingService();

  static const int displayUnitMinutes = 5;

  int ceilMinutes(int minutes) {
    if (minutes <= 0) {
      return 0;
    }
    return ((minutes + displayUnitMinutes - 1) ~/ displayUnitMinutes) *
        displayUnitMinutes;
  }

  DateTime ceilDateTime(DateTime value) {
    final totalMinutes = value.hour * 60 + value.minute;
    final roundedMinutes = ceilMinutes(totalMinutes);
    final dayOffset = roundedMinutes ~/ (24 * 60);
    final minuteOfDay = roundedMinutes % (24 * 60);

    return DateTime(
      value.year,
      value.month,
      value.day + dayOffset,
      minuteOfDay ~/ 60,
      minuteOfDay % 60,
    );
  }

  Duration ceilDuration(Duration duration) {
    return Duration(minutes: ceilMinutes(duration.inMinutes));
  }
}
