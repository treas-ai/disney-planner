import '../entities/trip_settings.dart';
import '../enums/preferred_time.dart';
import '../value_objects/time_allocation.dart';

class TimeAllocator {
  const TimeAllocator({this.facilityDurationMinutes = 60});

  final int facilityDurationMinutes;

  TimeAllocation allocate({
    required TripSettings settings,
    required PreferredTime preferredTime,
  }) {
    final startMinutes = _resolveStartMinutes(
      settings: settings,
      preferredTime: preferredTime,
    );

    final exitMinutes = _toMinutes(
      settings.exitTimeHour,
      settings.exitTimeMinute,
    );

    final safeStartMinutes = startMinutes.clamp(
      _toMinutes(settings.entryTimeHour, settings.entryTimeMinute),
      exitMinutes,
    );

    final endMinutes = (safeStartMinutes + facilityDurationMinutes).clamp(
      safeStartMinutes,
      exitMinutes,
    );

    return TimeAllocation(
      startHour: safeStartMinutes ~/ 60,
      startMinute: safeStartMinutes % 60,
      endHour: endMinutes ~/ 60,
      endMinute: endMinutes % 60,
    );
  }

  int _resolveStartMinutes({
    required TripSettings settings,
    required PreferredTime preferredTime,
  }) {
    final entryMinutes = _toMinutes(
      settings.entryTimeHour,
      settings.entryTimeMinute,
    );

    switch (preferredTime) {
      case PreferredTime.morning:
        return entryMinutes;

      case PreferredTime.afternoon:
        return _laterOf(entryMinutes, _toMinutes(13, 0));

      case PreferredTime.evening:
        return _laterOf(entryMinutes, _toMinutes(17, 0));

      case PreferredTime.anytime:
        return entryMinutes;
    }
  }

  int _toMinutes(int hour, int minute) {
    return hour * 60 + minute;
  }

  int _laterOf(int first, int second) {
    return first >= second ? first : second;
  }
}
