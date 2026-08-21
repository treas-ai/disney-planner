import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/time_band_wait_profile.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/entities/wait_time_range.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/wait_time_band.dart';
import 'package:disney_planner/domain/services/schedule_engine.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

Facility _attraction() {
  return const Facility(
    id: 'tdl_test_a_001',
    parkId: 'tokyo_disneyland',
    areaId: 'tdl_test_area',
    name: '待ち時間予測テスト施設',
    category: FacilityCategory.attraction,
    coordinate: Coordinate(latitude: 0, longitude: 0),
    durationMinutes: 10,
  );
}

TripSettings _settings() {
  return TripSettings.initial().copyWith(
    parkId: 'tokyo_disneyland',
    visitDateIso: '2026-08-20T00:00:00.000',
    entryTimeHour: 9,
    entryTimeMinute: 0,
    exitTimeHour: 21,
    exitTimeMinute: 0,
    wantsBreakfast: false,
    wantsLunch: false,
    wantsDinner: false,
  );
}

TimeBandWaitProfile _profile({required WaitTimeRange openingRange}) {
  return TimeBandWaitProfile(
    facilityId: 'tdl_test_a_001',
    parkId: 'tokyo_disneyland',
    ranges: {
      WaitTimeBand.afterOpening: openingRange,
    },
    source: 'ThemeParks.wiki',
    calculatedAt: DateTime.utc(2026, 8, 20, 4),
    sampleCount: 42,
  );
}

void main() {
  test('ScheduleEngine uses the time-band wait profile for planned wait time', () {
    final facility = _attraction();
    final schedule = const ScheduleEngine().generate(
      settings: _settings(),
      facilities: [facility],
      preferences: [PlanPreference.initial(facilityId: facility.id)],
      waitProfiles: [
        _profile(
          openingRange: const WaitTimeRange(
            minMinutes: 10,
            typicalMinutes: 17,
            maxMinutes: 25,
          ),
        ),
      ],
    );

    final item = schedule.items.singleWhere(
      (item) => item.facilityId == facility.id,
    );

    expect(item.estimatedWaitMinutes, 17);
    expect(item.experienceMinutes, 10);
    expect(item.waitEstimateSource, contains('実績待ち時間プロファイル'));
    expect(item.waitEstimateSource, contains('開園直後'));
    expect(item.waitEstimateSource, contains('サンプル42件'));

    final start = item.startHour * 60 + item.startMinute;
    final end = item.endHour * 60 + item.endMinute;
    expect(end - start, 27);
  });

  test('empty 0/0/0 band is not mistaken for a real zero-minute wait', () {
    final facility = _attraction();
    final schedule = const ScheduleEngine().generate(
      settings: _settings(),
      facilities: [facility],
      preferences: [PlanPreference.initial(facilityId: facility.id)],
      waitProfiles: [
        _profile(
          openingRange: const WaitTimeRange(
            minMinutes: 0,
            typicalMinutes: 0,
            maxMinutes: 0,
          ),
        ),
      ],
    );

    final item = schedule.items.singleWhere(
      (item) => item.facilityId == facility.id,
    );

    expect(item.estimatedWaitMinutes, 30);
    expect(item.waitEstimateSource, '待ち時間データ未登録のため優先度別の安全側暫定値');
  });

  test('missing target band uses the nearest valid band from the same facility', () {
    final facility = _attraction();
    final profile = TimeBandWaitProfile(
      facilityId: facility.id,
      parkId: facility.parkId,
      ranges: const {
        WaitTimeBand.afterOpening: WaitTimeRange(
          minMinutes: 10, typicalMinutes: 20, maxMinutes: 30),
        WaitTimeBand.beforeLunch: WaitTimeRange(
          minMinutes: 0, typicalMinutes: 0, maxMinutes: 0),
        WaitTimeBand.afterLunch: WaitTimeRange(
          minMinutes: 25, typicalMinutes: 35, maxMinutes: 45),
      },
      source: 'ThemeParks.wiki GitHub history',
      calculatedAt: DateTime.utc(2026, 8, 21),
      sampleCount: 50,
    );

    final settings = _settings().copyWith(entryTimeHour: 11, entryTimeMinute: 0);
    final schedule = const ScheduleEngine().generate(
      settings: settings,
      facilities: [facility],
      preferences: [PlanPreference.initial(facilityId: facility.id)],
      waitProfiles: [profile],
    );
    final item = schedule.items.singleWhere((item) => item.facilityId == facility.id);

    // beforeLunch is equally close to afterOpening and afterLunch.
    // The safer (larger typicalMinutes) afterLunch value wins.
    expect(item.estimatedWaitMinutes, 35);
    expect(item.waitEstimateSource, contains('昼前を昼後から近接参照'));
  });

  test('profile with no valid bands keeps the priority fallback', () {
    final facility = _attraction();
    final profile = TimeBandWaitProfile(
      facilityId: facility.id,
      parkId: facility.parkId,
      ranges: const {
        WaitTimeBand.afterOpening: WaitTimeRange(
          minMinutes: 0, typicalMinutes: 0, maxMinutes: 0),
        WaitTimeBand.beforeLunch: WaitTimeRange(
          minMinutes: 0, typicalMinutes: 0, maxMinutes: 0),
      },
      source: 'ThemeParks.wiki GitHub history',
      calculatedAt: DateTime.utc(2026, 8, 21),
      sampleCount: 0,
    );

    final schedule = const ScheduleEngine().generate(
      settings: _settings(),
      facilities: [facility],
      preferences: [PlanPreference.initial(facilityId: facility.id)],
      waitProfiles: [profile],
    );
    final item = schedule.items.singleWhere((item) => item.facilityId == facility.id);

    expect(item.estimatedWaitMinutes, 30);
    expect(item.waitEstimateSource, '待ち時間データ未登録のため優先度別の安全側暫定値');
  });

}
