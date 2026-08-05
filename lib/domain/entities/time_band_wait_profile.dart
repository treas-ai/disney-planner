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
    );
  }

  final String facilityId;
  final String parkId;
  final Map<WaitTimeBand, WaitTimeRange> ranges;
  final String source;
  final DateTime calculatedAt;
  final int sampleCount;

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
    };
  }
}
