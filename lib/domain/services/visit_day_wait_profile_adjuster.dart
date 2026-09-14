import '../entities/crowd_factor_profile.dart';
import '../entities/time_band_wait_profile.dart';
import '../entities/visit_day_context.dart';
import '../entities/wait_time_range.dart';
import '../enums/wait_time_band.dart';
import 'time_rounding_service.dart';

class VisitDayWaitProfileAdjuster {
  const VisitDayWaitProfileAdjuster({
    this.timeRoundingService = const TimeRoundingService(),
  });

  final TimeRoundingService timeRoundingService;

  List<TimeBandWaitProfile> apply({
    required List<TimeBandWaitProfile> profiles,
    required List<CrowdFactorProfile> factors,
    required VisitDayContext context,
    int minimumSamples = 30,
    double maximumMultiplier = 1.75,
  }) {
    if (profiles.isEmpty) {
      return profiles;
    }

    final adjusted = <TimeBandWaitProfile>[];
    for (final profile in profiles) {
      var changed = false;
      final appliedKeys = <String>{};
      final ranges = <WaitTimeBand, WaitTimeRange>{};

      for (final entry in profile.ranges.entries) {
        final band = entry.key;
        var range = entry.value;
        final recent = context.hasSpecialContext
            ? null
            : profile.recentRangeFor(context.date.weekday, band);
        final usesRecent = recent != null && (recent.sampleCount ?? 0) >= 2;
        if (usesRecent) {
          range = recent;
          changed = true;
          appliedKeys.add('recent4w:weekday:${context.date.weekday}|band:${band.name}');
        }
        final selected = _selectFactor(
          profile: profile,
          factors: factors,
          context: context,
          band: band,
          minimumSamples: minimumSamples,
          skipWeekdayAndSeason: usesRecent,
        );
        if (selected == null) {
          ranges[band] = range;
          continue;
        }

        final multiplier = selected.factor
            .clamp(1.0, maximumMultiplier)
            .toDouble();
        if (multiplier <= 1.001) {
          ranges[band] = range;
          continue;
        }

        changed = true;
        appliedKeys.add(selected.dimensionKey);
        ranges[band] = WaitTimeRange(
          minMinutes: _adjust(range.minMinutes, multiplier),
          typicalMinutes: _adjust(range.typicalMinutes, multiplier),
          maxMinutes: _adjust(range.maxMinutes, multiplier),
          sampleCount: range.sampleCount,
        );
      }

      if (!changed) {
        adjusted.add(profile);
        continue;
      }

      final conditionLabel = context.summary.isEmpty
          ? '曜日・季節実績'
          : context.summary;
      adjusted.add(
        TimeBandWaitProfile(
          facilityId: profile.facilityId,
          parkId: profile.parkId,
          ranges: Map<WaitTimeBand, WaitTimeRange>.unmodifiable(ranges),
          source: '${profile.source} / 来園日条件補正:$conditionLabel '
              '(${appliedKeys.join(', ')})',
          calculatedAt: profile.calculatedAt,
          sampleCount: profile.sampleCount,
          recentWeekdayRanges: profile.recentWeekdayRanges,
        ),
      );
    }

    return List<TimeBandWaitProfile>.unmodifiable(adjusted);
  }

  _SelectedVisitDayFactor? _selectFactor({
    required TimeBandWaitProfile profile,
    required List<CrowdFactorProfile> factors,
    required VisitDayContext context,
    required WaitTimeBand band,
    required int minimumSamples,
    bool skipWeekdayAndSeason = false,
  }) {
    final specificKeys = <String>{
      if (!skipWeekdayAndSeason)
        'weekday:${context.date.weekday}|band:${band.name}',
      if (context.isNationalHoliday) 'holiday:true|band:${band.name}',
      ...context.eventIds.map((id) => 'event:$id|band:${band.name}'),
    };
    final generalKeys = context.factorDimensionKeys().where((key) {
      if (!skipWeekdayAndSeason) return true;
      return !key.startsWith('weekday:') && !key.startsWith('season:');
    }).toSet();

    final specific = _strongestMeasuredFactor(
      profile: profile,
      factors: factors,
      keys: specificKeys,
      minimumSamples: minimumSamples,
      minimumSpanDays: 7,
    );
    if (specific != null) {
      return specific;
    }

    return _strongestMeasuredFactor(
      profile: profile,
      factors: factors,
      keys: generalKeys,
      minimumSamples: minimumSamples,
      minimumSpanDays: 14,
    );
  }

  _SelectedVisitDayFactor? _strongestMeasuredFactor({
    required TimeBandWaitProfile profile,
    required List<CrowdFactorProfile> factors,
    required Set<String> keys,
    required int minimumSamples,
    required int minimumSpanDays,
  }) {
    CrowdFactorProfile? selected;
    String? selectedKey;
    var selectedFactor = 1.0;

    for (final factor in factors) {
      if (factor.parkId != profile.parkId ||
          factor.facilityId != profile.facilityId ||
          factor.sampleCount < minimumSamples ||
          factor.sampleEnd.difference(factor.sampleStart).inDays <
              minimumSpanDays) {
        continue;
      }
      String? matchingKey;
      for (final dimension in factor.dimensions) {
        if (keys.contains(dimension)) {
          matchingKey = dimension;
          break;
        }
      }
      if (matchingKey == null || factor.factor <= selectedFactor) {
        continue;
      }
      selected = factor;
      selectedKey = matchingKey;
      selectedFactor = factor.factor;
    }

    if (selected == null || selectedKey == null) {
      return null;
    }
    return _SelectedVisitDayFactor(
      factor: selected.factor,
      dimensionKey: selectedKey,
    );
  }

  int _adjust(int minutes, double multiplier) {
    if (minutes <= 0) return minutes;
    return timeRoundingService.ceilMinutes((minutes * multiplier).round());
  }
}

class _SelectedVisitDayFactor {
  const _SelectedVisitDayFactor({
    required this.factor,
    required this.dimensionKey,
  });

  final double factor;
  final String dimensionKey;
}
