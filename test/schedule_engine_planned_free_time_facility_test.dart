import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/time_band_wait_profile.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/entities/wait_time_range.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/fixed_time_status.dart';
import 'package:disney_planner/domain/enums/wait_time_band.dart';
import 'package:disney_planner/domain/services/schedule_engine.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('空き時間でユーザーが選んだ通常待機施設を目標時刻へ配置する', () {
    final facility = Facility(
      id: 'manual_gap_attraction',
      parkId: 'tokyo_disneyland',
      areaId: 'area_a',
      name: 'Manual Gap Attraction',
      category: FacilityCategory.attraction,
      coordinate: const Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 10,
    );
    final preference = PlanPreference.initial(facilityId: facility.id).copyWith(
      fixedTimeStatus: FixedTimeStatus.planned,
      scheduledAccessTime: '14:00',
    );
    final profile = TimeBandWaitProfile(
      facilityId: facility.id,
      parkId: facility.parkId,
      ranges: const {
        WaitTimeBand.aroundShows: WaitTimeRange(
          minMinutes: 35,
          typicalMinutes: 45,
          maxMinutes: 55,
          sampleCount: 30,
        ),
      },
      source: 'planned-gap-test',
      calculatedAt: DateTime.utc(2026, 9, 10),
      sampleCount: 30,
    );

    final schedule = const ScheduleEngine().generate(
      settings: TripSettings.initial().copyWith(
        parkId: 'tokyo_disneyland',
        visitDateIso: '2026-10-05T00:00:00.000',
        entryTimeHour: 9,
        entryTimeMinute: 0,
        exitTimeHour: 21,
        exitTimeMinute: 0,
        wantsBreakfast: false,
        wantsLunch: false,
        wantsDinner: false,
      ),
      facilities: [facility],
      preferences: [preference],
      waitProfiles: [profile],
    );

    final item = schedule.items.firstWhere(
      (item) => item.facilityId == facility.id,
    );
    expect(item.startTimeLabel, '14:00');
    expect(item.endTimeLabel, '14:55');
    expect(item.estimatedWaitMinutes, 45);
    expect(item.experienceMinutes, 10);
    expect(item.waitEstimateSource, contains('実績待ち時間プロファイル'));
    expect(item.reason, contains('空き時間改善'));
  });
  test('空き時間で選んだ乗り放題施設は優先入口バッファで配置する', () {
    final facility = Facility(
      id: 'manual_gap_unlimited',
      parkId: 'tokyo_disneyland',
      areaId: 'area_a',
      name: 'Manual Gap Unlimited',
      category: FacilityCategory.attraction,
      coordinate: const Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 2,
    );
    final preference = PlanPreference.initial(facilityId: facility.id).copyWith(
      fixedTimeStatus: FixedTimeStatus.planned,
      scheduledAccessTime: '14:00',
    );

    final schedule = const ScheduleEngine().generate(
      settings: TripSettings.initial().copyWith(
        parkId: 'tokyo_disneyland',
        visitDateIso: '2026-10-05T00:00:00.000',
        entryTimeHour: 9,
        entryTimeMinute: 0,
        exitTimeHour: 21,
        exitTimeMinute: 0,
        wantsBreakfast: false,
        wantsLunch: false,
        wantsDinner: false,
        usesVacationPackage: true,
        hasUnlimitedAttractionRides: true,
      ),
      facilities: [facility],
      preferences: [preference],
      unlimitedRideBufferMinutes: {facility.id: 15},
    );

    final item = schedule.items.firstWhere(
      (item) => item.facilityId == facility.id,
    );
    expect(item.startTimeLabel, '14:00');
    expect(item.endTimeLabel, '14:17');
    expect(item.estimatedWaitMinutes, 15);
    expect(item.experienceMinutes, 2);
    expect(item.waitEstimateSource, contains('バケーションパッケージ乗り放題'));
    expect(item.reason, contains('優先入口利用バッファ'));
  });

}
