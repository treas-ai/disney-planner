import '../enums/wait_time_band.dart';
import 'wait_time_range.dart';

class TimeBandWaitProfile {
  const TimeBandWaitProfile({
    required this.facilityId,
    required this.parkId,
    required this.ranges,
    required this.source,
    required this.calculatedAt,
    required this.sampleCount,
    this.recentWeekdayRanges = const {},
  });

  factory TimeBandWaitProfile.fromJson(Map<String, dynamic> json) {
    final rawRanges =
        json['ranges'] as Map<String, dynamic>? ?? const <String, dynamic>{};

    return TimeBandWaitProfile(
      facilityId: json['facilityId'] as String? ?? '',
      parkId: json['parkId'] as String? ?? '',
      ranges: {
        for (final entry in rawRanges.entries)
          WaitTimeBand.fromName(entry.key): WaitTimeRange.fromJson(
            entry.value as Map<String, dynamic>,
          ),
      },
      source: json['source'] as String? ?? '未設定',
      calculatedAt:
          DateTime.tryParse(json['calculatedAt'] as String? ?? '') ??
          DateTime(2000),
      sampleCount: json['sampleCount'] as int? ?? 0,
      recentWeekdayRanges: {
        for (final weekdayEntry in
            (json['recentWeekdayRanges'] as Map<String, dynamic>? ??
                    const <String, dynamic>{})
                .entries)
          int.parse(weekdayEntry.key): {
              for (final bandEntry in
                  (weekdayEntry.value as Map<String, dynamic>).entries)
                WaitTimeBand.fromName(bandEntry.key): WaitTimeRange.fromJson(
                  bandEntry.value as Map<String, dynamic>,
                ),
            },
      },
    );
  }

  final String facilityId;
  final String parkId;
  final Map<WaitTimeBand, WaitTimeRange> ranges;
  final String source;
  final DateTime calculatedAt;
  final int sampleCount;

  /// Recency-weighted daily-median ranges for the latest four ordinary
  /// occurrences of each weekday. Keys are DateTime.weekday (1..7).
  /// Holiday/event observations are deliberately excluded so an ordinary
  /// Tuesday is not distorted by a special Tuesday.
  final Map<int, Map<WaitTimeBand, WaitTimeRange>> recentWeekdayRanges;

  WaitTimeRange? recentRangeFor(int weekday, WaitTimeBand band) =>
      recentWeekdayRanges[weekday]?[band];

  WaitTimeRange? rangeFor(WaitTimeBand band) => ranges[band];

  Map<String, dynamic> toJson() {
    return {
      'facilityId': facilityId,
      'parkId': parkId,
      'ranges': {
        for (final entry in ranges.entries)
          entry.key.name: entry.value.toJson(),
      },
      'source': source,
      'calculatedAt': calculatedAt.toIso8601String(),
      'sampleCount': sampleCount,
      if (recentWeekdayRanges.isNotEmpty)
        'recentWeekdayRanges': {
          for (final weekdayEntry in recentWeekdayRanges.entries)
            weekdayEntry.key.toString(): {
              for (final bandEntry in weekdayEntry.value.entries)
                bandEntry.key.name: bandEntry.value.toJson(),
            },
        },
    };
  }
}
