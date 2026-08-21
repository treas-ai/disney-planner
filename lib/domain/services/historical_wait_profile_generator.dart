import '../entities/crowd_factor_profile.dart';
import '../entities/historical_wait_record.dart';
import '../entities/time_band_wait_profile.dart';
import '../entities/wait_time_range.dart';
import '../enums/crowd_factor_confidence.dart';
import '../enums/wait_time_band.dart';

class HistoricalWaitGenerationResult {
  const HistoricalWaitGenerationResult({required this.factors, required this.waitProfiles});
  final List<CrowdFactorProfile> factors;
  final List<TimeBandWaitProfile> waitProfiles;
}

class HistoricalWaitProfileGenerator {
  const HistoricalWaitProfileGenerator({this.methodVersion = '5.1.1'});
  final String methodVersion;

  HistoricalWaitGenerationResult generate({required String parkId, required List<HistoricalWaitRecord> records, DateTime? calculatedAt}) {
    final usable = records.where((record) => record.parkId == parkId && !record.isExcluded).toList(growable: false);
    final now = calculatedAt ?? DateTime.now().toUtc();
    if (usable.isEmpty) return const HistoricalWaitGenerationResult(factors: [], waitProfiles: []);
    final byFacility = <String, List<HistoricalWaitRecord>>{};
    for (final record in usable) {
      byFacility.putIfAbsent(record.facilityId, () => []).add(record);
    }
    final factors = <CrowdFactorProfile>[];
    final profiles = <TimeBandWaitProfile>[];
    for (final entry in byFacility.entries) {
      final samples = entry.value..sort((a, b) => a.observedAt.compareTo(b.observedAt));
      final facilityMedian = _percentile(samples.map((e) => e.waitMinutes).toList(), 0.5).toDouble();
      profiles.add(TimeBandWaitProfile(
        facilityId: entry.key,
        parkId: parkId,
        ranges: {
          for (final band in WaitTimeBand.values)
            band: _range(samples.where((sample) => _bandFor(sample.observedAt) == band).map((e) => e.waitMinutes).toList()),
        },
        source: samples.map((e) => e.source).toSet().join(', '),
        calculatedAt: now,
        sampleCount: samples.length,
      ));
      final groups = <String, List<HistoricalWaitRecord>>{};
      for (final sample in samples) {
        final keys = <String>[
          'weekday:${sample.observedAt.weekday}',
          'season:${_season(sample.observedAt.month)}',
          if (sample.isHoliday) 'holiday:true',
          ...sample.eventIds.map((id) => 'event:$id'),
        ];
        for (final key in keys) {
          groups.putIfAbsent(key, () => []).add(sample);
        }
      }
      for (final group in groups.entries) {
        final median = _percentile(group.value.map((e) => e.waitMinutes).toList(), 0.5).toDouble();
        factors.add(CrowdFactorProfile(
          parkId: parkId,
          facilityId: entry.key,
          factor: facilityMedian <= 0
              ? 1
              : (median / facilityMedian).clamp(0.25, 4).toDouble(),
          source: group.value.map((e) => e.source).toSet().join(', '),
          calculatedAt: now,
          sampleStart: group.value.map((e) => e.observedAt).reduce((a, b) => a.isBefore(b) ? a : b),
          sampleEnd: group.value.map((e) => e.observedAt).reduce((a, b) => a.isAfter(b) ? a : b),
          sampleCount: group.value.length,
          excludedCount: records.where((e) => e.parkId == parkId && e.facilityId == entry.key && e.isExcluded).length,
          confidence: _confidence(group.value.length),
          methodVersion: methodVersion,
          dimensions: [group.key],
        ));
      }
    }
    return HistoricalWaitGenerationResult(factors: List.unmodifiable(factors), waitProfiles: List.unmodifiable(profiles));
  }

  WaitTimeRange _range(List<int> values) {
    if (values.isEmpty) {
      return const WaitTimeRange(
        minMinutes: 0,
        typicalMinutes: 0,
        maxMinutes: 0,
        sampleCount: 0,
      );
    }
    return WaitTimeRange(
      minMinutes: _percentile(values, 0.1),
      typicalMinutes: _percentile(values, 0.5),
      maxMinutes: _percentile(values, 0.9),
      sampleCount: values.length,
    );
  }

  int _percentile(List<int> values, double percentile) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final index = ((sorted.length - 1) * percentile).round();
    return sorted[index];
  }

  CrowdFactorConfidence _confidence(int count) => count >= 100 ? CrowdFactorConfidence.high : count >= 30 ? CrowdFactorConfidence.medium : CrowdFactorConfidence.low;
  String _season(int month) => month == 12 || month <= 2 ? 'winter' : month <= 5 ? 'spring' : month <= 8 ? 'summer' : 'autumn';

  WaitTimeBand _bandFor(DateTime time) {
    // ThemeParks.wiki履歴はUTC (Z) で保存されるため、
    // 東京ディズニーリゾートの時間帯判定はJSTへ変換してから行う。
    // timezone packageに依存せず、TDRは通年UTC+9（DSTなし）として扱う。
    final local = time.isUtc ? time.add(const Duration(hours: 9)) : time;
    final minute = local.hour * 60 + local.minute;
    if (minute < 660) return WaitTimeBand.afterOpening;
    if (minute < 720) return WaitTimeBand.beforeLunch;
    if (minute < 900) return WaitTimeBand.afterLunch;
    if (minute < 1020) return WaitTimeBand.aroundShows;
    if (minute < 1080) return WaitTimeBand.beforeDinner;
    if (minute < 1200) return WaitTimeBand.afterDinner;
    return WaitTimeBand.beforeClosing;
  }
}
