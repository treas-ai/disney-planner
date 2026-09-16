enum DpaTimingRating { good, caution, avoid }

class DpaBlockedWindow {
  const DpaBlockedWindow({
    required this.startMinutes,
    required this.endMinutes,
  });

  final int startMinutes;
  final int endMinutes;

  bool contains(int minutes) =>
      startMinutes <= minutes && minutes <= endMinutes;
}

class DpaTimingRange {
  const DpaTimingRange({
    required this.startMinutes,
    required this.endMinutes,
    required this.rating,
  });

  final int startMinutes;
  final int endMinutes;
  final DpaTimingRating rating;
}

class DpaTimingAdvisor {
  const DpaTimingAdvisor();

  DpaTimingRating rateStart({
    required int startMinutes,
    required List<DpaBlockedWindow> blockedWindows,
  }) {
    var safeSamples = 0;
    for (var offset = 0; offset < 60; offset += 10) {
      final candidate = startMinutes + offset;
      final blocked = blockedWindows.any(
        (window) => window.contains(candidate),
      );
      if (!blocked) safeSamples++;
    }
    if (safeSamples == 0) return DpaTimingRating.avoid;
    if (safeSamples <= 2) return DpaTimingRating.caution;
    return DpaTimingRating.good;
  }

  List<DpaTimingRange> buildRanges({
    required List<DpaBlockedWindow> blockedWindows,
    int startMinutes = 8 * 60,
    int endMinutes = 21 * 60,
  }) {
    final ranges = <DpaTimingRange>[];
    DpaTimingRating? current;
    int? rangeStart;
    for (var minute = startMinutes; minute <= endMinutes; minute += 10) {
      final rating = rateStart(
        startMinutes: minute,
        blockedWindows: blockedWindows,
      );
      if (current == null) {
        current = rating;
        rangeStart = minute;
        continue;
      }
      if (rating != current) {
        ranges.add(DpaTimingRange(
          startMinutes: rangeStart!,
          endMinutes: minute - 10,
          rating: current,
        ));
        current = rating;
        rangeStart = minute;
      }
    }
    if (current != null && rangeStart != null) {
      ranges.add(DpaTimingRange(
        startMinutes: rangeStart,
        endMinutes: endMinutes,
        rating: current,
      ));
    }
    return List<DpaTimingRange>.unmodifiable(ranges);
  }
}
