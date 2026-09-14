import 'package:disney_planner/domain/entities/crowd_factor_profile.dart';
import 'package:disney_planner/domain/entities/time_band_wait_profile.dart';
import 'package:disney_planner/domain/entities/visit_day_context.dart';
import 'package:disney_planner/domain/entities/wait_time_range.dart';
import 'package:disney_planner/domain/enums/crowd_factor_confidence.dart';
import 'package:disney_planner/domain/enums/wait_time_band.dart';
import 'package:disney_planner/domain/services/visit_day_wait_profile_adjuster.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VisitDayRuleSet', () {
    final rules = VisitDayRuleSet.fromJson({
      'nationalHolidays': [
        {'id': 'holiday', 'name': '休日', 'date': '2026-09-22'},
      ],
      'regionalDays': [
        {'id': 'tokyo_day', 'name': '都民の日', 'monthDay': '10-01'},
        {'id': 'chiba_day', 'name': '千葉県民の日', 'monthDay': '06-15'},
        {'id': 'saitama_day', 'name': '埼玉県民の日', 'monthDay': '11-14'},
      ],
      'specialDays': [
        {'id': 'goods_launch', 'name': '新グッズ発売初日', 'date': '2026-10-15'},
      ],
    });

    test('recognizes national holiday', () {
      final context = rules.contextFor(DateTime(2026, 9, 22));
      expect(context.isNationalHoliday, isTrue);
      expect(context.nationalHolidayName, '休日');
      expect(context.factorDimensionKeys(), contains('holiday:true'));
    });

    test('recognizes Tokyo Chiba and Saitama regional days', () {
      expect(
        rules.contextFor(DateTime(2026, 10, 1)).eventIds,
        contains('tokyo_day'),
      );
      expect(
        rules.contextFor(DateTime(2026, 6, 15)).eventIds,
        contains('chiba_day'),
      );
      expect(
        rules.contextFor(DateTime(2026, 11, 14)).eventIds,
        contains('saitama_day'),
      );
    });


    test('detects three-day-or-longer holiday blocks and position', () {
      final longWeekendRules = VisitDayRuleSet.fromJson({
        'nationalHolidays': [
          {'id': 'respect', 'name': '敬老の日', 'date': '2026-09-21'},
          {'id': 'citizen', 'name': '休日', 'date': '2026-09-22'},
          {'id': 'autumn', 'name': '秋分の日', 'date': '2026-09-23'},
        ],
        'regionalDays': const [],
        'specialDays': const [],
      });
      final context = longWeekendRules.contextFor(DateTime(2026, 9, 22));
      expect(context.eventIds, contains('long_weekend_3plus'));
      expect(context.eventIds, contains('long_weekend_middle'));
    });

    test('supports data-driven special-day tags', () {
      final context = rules.contextFor(DateTime(2026, 10, 15));
      expect(context.specialEventIds, contains('goods_launch'));
      expect(context.factorDimensionKeys(), contains('event:goods_launch'));
    });
  });


  test('weekday x time-band factor is preferred when sufficiently measured', () {
    final profile = TimeBandWaitProfile(
      facilityId: 'ride',
      parkId: 'tokyo_disneyland',
      ranges: const {
        WaitTimeBand.afterLunch: WaitTimeRange(
          minMinutes: 20,
          typicalMinutes: 40,
          maxMinutes: 60,
          sampleCount: 100,
        ),
      },
      source: 'history',
      calculatedAt: DateTime(2026, 9, 1),
      sampleCount: 100,
    );
    final date = DateTime(2026, 9, 12); // Saturday
    final factor = CrowdFactorProfile(
      parkId: 'tokyo_disneyland',
      facilityId: 'ride',
      factor: 1.5,
      source: 'history',
      calculatedAt: DateTime(2026, 9, 1),
      sampleStart: DateTime(2026, 8, 1),
      sampleEnd: DateTime(2026, 8, 29),
      sampleCount: 40,
      excludedCount: 0,
      confidence: CrowdFactorConfidence.medium,
      methodVersion: 'test',
      dimensions: ['weekday:${date.weekday}|band:afterLunch'],
    );

    final result = const VisitDayWaitProfileAdjuster().apply(
      profiles: [profile],
      factors: [factor],
      context: VisitDayContext(date: date, isNationalHoliday: false),
    );

    expect(
      result.single.rangeFor(WaitTimeBand.afterLunch)!.typicalMinutes,
      60,
    );
    expect(result.single.source, contains('|band:afterLunch'));
  });

  test('wait profile uses strongest measured date factor without multiplying', () {
    final profile = TimeBandWaitProfile(
      facilityId: 'ride',
      parkId: 'tokyo_disneyland',
      ranges: const {
        WaitTimeBand.afterLunch: WaitTimeRange(
          minMinutes: 30,
          typicalMinutes: 40,
          maxMinutes: 60,
          sampleCount: 100,
        ),
      },
      source: 'history',
      calculatedAt: DateTime(2026, 9, 1),
      sampleCount: 100,
    );
    final base = DateTime(2026, 9, 12);
    final factors = [
      _factor('weekday:${base.weekday}', 1.20, 80),
      _factor('season:autumn', 1.10, 80),
      _factor('holiday:true', 1.50, 10),
    ];
    final context = VisitDayContext(
      date: base,
      isNationalHoliday: true,
      nationalHolidayName: '休日',
    );

    final result = const VisitDayWaitProfileAdjuster().apply(
      profiles: [profile],
      factors: factors,
      context: context,
    );

    expect(
      result.single.rangeFor(WaitTimeBand.afterLunch)!.typicalMinutes,
      50,
    );
    expect(result.single.source, contains('weekday:'));
    expect(result.single.source, isNot(contains('×1.50')));
  });
}

CrowdFactorProfile _factor(String dimension, double factor, int sampleCount) {
  return CrowdFactorProfile(
    parkId: 'tokyo_disneyland',
    facilityId: 'ride',
    factor: factor,
    source: 'history',
    calculatedAt: DateTime(2026, 9, 1),
    sampleStart: DateTime(2026, 1, 1),
    sampleEnd: DateTime(2026, 8, 31),
    sampleCount: sampleCount,
    excludedCount: 0,
    confidence: CrowdFactorConfidence.medium,
    methodVersion: 'test',
    dimensions: [dimension],
  );
}
