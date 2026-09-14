import '../entities/crowd_factor_profile.dart';
import '../entities/historical_wait_record.dart';
import '../entities/time_band_wait_profile.dart';
import '../entities/wait_time_range.dart';
import '../enums/crowd_factor_confidence.dart';
import '../enums/wait_time_band.dart';
import 'time_rounding_service.dart';

class HistoricalWaitGenerationResult {
  const HistoricalWaitGenerationResult({required this.factors, required this.waitProfiles});
  final List<CrowdFactorProfile> factors;
  final List<TimeBandWaitProfile> waitProfiles;
}

class HistoricalWaitProfileGenerator {
  const HistoricalWaitProfileGenerator({
    this.methodVersion = '5.2.0',
    this.timeRoundingService = const TimeRoundingService(),
  });
  final String methodVersion;
  final TimeRoundingService timeRoundingService;

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
        recentWeekdayRanges: _recentWeekdayRanges(samples),
      ));
      final groups = <String, List<HistoricalWaitRecord>>{};
      for (final sample in samples) {
        final local = _localTime(sample.observedAt);
        final band = _bandFor(sample.observedAt);
        final keys = <String>[
          'weekday:${local.weekday}',
          'season:${_season(local.month)}',
          'weekday:${local.weekday}|band:${band.name}',
          if (sample.isHoliday) ...[
            'holiday:true',
            'holiday:true|band:${band.name}',
          ],
          ...sample.eventIds.expand(
            (id) => ['event:$id', 'event:$id|band:${band.name}'],
          ),
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

  Map<int, Map<WaitTimeBand, WaitTimeRange>> _recentWeekdayRanges(
    List<HistoricalWaitRecord> samples,
  ) {
    // Collapse the 5-minute collector samples into one median per local day
    // and time band first. This prevents a day with more polling samples from
    // receiving more influence merely because it was observed more often.
    final daily = <String, List<int>>{};
    for (final sample in samples) {
      if (sample.isHoliday || sample.eventIds.isNotEmpty) continue;
      final local = _localTime(sample.observedAt);
      final band = _bandFor(sample.observedAt);
      final dayKey = '${local.year.toString().padLeft(4, '0')}-'
          '${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';
      daily.putIfAbsent('$dayKey|${local.weekday}|${band.name}', () => <int>[])
          .add(sample.waitMinutes);
    }

    final byWeekdayBand = <String, List<_DailyWaitMedian>>{};
    for (final entry in daily.entries) {
      final parts = entry.key.split('|');
      final date = DateTime.parse(parts[0]);
      final weekday = int.parse(parts[1]);
      final band = WaitTimeBand.fromName(parts[2]);
      byWeekdayBand
          .putIfAbsent('$weekday|${band.name}', () => <_DailyWaitMedian>[])
          .add(_DailyWaitMedian(
            date: date,
            minutes: _percentile(entry.value, 0.5),
          ));
    }

    final result = <int, Map<WaitTimeBand, WaitTimeRange>>{};
    for (final entry in byWeekdayBand.entries) {
      final parts = entry.key.split('|');
      final weekday = int.parse(parts[0]);
      final band = WaitTimeBand.fromName(parts[1]);
      final days = entry.value..sort((a, b) => b.date.compareTo(a.date));
      // "Latest four weeks" means the latest four matching weekday
      // occurrences, not a fixed 27-day window from the newest observation.
      // A Tuesday four occurrences back can be 28+ calendar days away when
      // the newest record is a later special day or another weekday.
      final latest = days.take(4).toList(growable: false);
      if (latest.isEmpty) continue;
      result.putIfAbsent(weekday, () => <WaitTimeBand, WaitTimeRange>{})[band] =
          _weightedRecentRange(latest);
    }
    return {
      for (final entry in result.entries)
        entry.key: Map<WaitTimeBand, WaitTimeRange>.unmodifiable(entry.value),
    };
  }

  WaitTimeRange _weightedRecentRange(List<_DailyWaitMedian> days) {
    const weights = <double>[0.50, 0.25, 0.15, 0.10];
    var weightedSum = 0.0;
    var weightSum = 0.0;
    var minMinutes = days.first.minutes;
    var maxMinutes = days.first.minutes;
    for (var i = 0; i < days.length; i++) {
      final weight = weights[i];
      final minutes = days[i].minutes;
      weightedSum += minutes * weight;
      weightSum += weight;
      if (minutes < minMinutes) minMinutes = minutes;
      if (minutes > maxMinutes) maxMinutes = minutes;
    }
    final typical = timeRoundingService.ceilMinutes(
      (weightedSum / weightSum).round(),
    );
    return WaitTimeRange(
      minMinutes: timeRoundingService.ceilMinutes(minMinutes),
      typicalMinutes: typical.clamp(
        timeRoundingService.ceilMinutes(minMinutes),
        timeRoundingService.ceilMinutes(maxMinutes),
      ).toInt(),
      maxMinutes: timeRoundingService.ceilMinutes(maxMinutes),
      // Here sampleCount intentionally means distinct local days, not raw
      // collector observations.
      sampleCount: days.length,
    );
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
      minMinutes: timeRoundingService.ceilMinutes(_percentile(values, 0.1)),
      typicalMinutes: timeRoundingService.ceilMinutes(_percentile(values, 0.5)),
      maxMinutes: timeRoundingService.ceilMinutes(_percentile(values, 0.9)),
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

  DateTime _localTime(DateTime time) =>
      time.isUtc ? time.add(const Duration(hours: 9)) : time;

  WaitTimeBand _bandFor(DateTime time) {
    // ThemeParks.wiki履歴はUTC (Z) で保存されるため、
    // 東京ディズニーリゾートの時間帯判定はJSTへ変換してから行う。
    // timezone packageに依存せず、TDRは通年UTC+9（DSTなし）として扱う。
    final local = _localTime(time);
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

class _DailyWaitMedian {
  const _DailyWaitMedian({required this.date, required this.minutes});
  final DateTime date;
  final int minutes;
}
