import 'package:flutter_test/flutter_test.dart';
import 'package:disney_planner/ai/planner/ai_day_planner.dart';
import 'package:disney_planner/domain/entities/dpa_strategy.dart';
import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/time_band_wait_profile.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/entities/wait_time_range.dart';
import 'package:disney_planner/domain/enums/facility_access_method.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/wait_time_band.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';

void main() {
  test('空の候補でも入退園を含むスケジュールを生成できる', () {
    const planner = AiDayPlanner();
    final result = planner.generate(
      settings: TripSettings.initial(),
      facilities: const [],
      preferences: const [],
      waitProfiles: const [],
      dpaStrategy: const DpaStrategy.disabled(),
    );

    expect(result.rankedCandidates, isEmpty);
    expect(result.selectedCandidates, isEmpty);
    expect(result.dpaFacilityIds, isEmpty);
    expect(result.schedule.items, isNotEmpty);
  });

  test('DPA利用可なら無効戦略でも混雑DPA対象を1件だけ自動選択する', () {
    const planner = AiDayPlanner();
    const facility = Facility(
      id: 'dpa_popular',
      parkId: 'tokyo_disneyland',
      areaId: 'tdl_test',
      name: 'DPA人気施設',
      category: FacilityCategory.attraction,
      coordinate: Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 10,
      supportsDpa: true,
    );
    final profile = TimeBandWaitProfile(
      facilityId: facility.id,
      parkId: facility.parkId,
      ranges: const {
        WaitTimeBand.afterLunch: WaitTimeRange(
          minMinutes: 80,
          typicalMinutes: 90,
          maxMinutes: 100,
          sampleCount: 10,
        ),
        WaitTimeBand.afterOpening: WaitTimeRange(
          minMinutes: 70,
          typicalMinutes: 80,
          maxMinutes: 90,
          sampleCount: 10,
        ),
      },
      source: 'test history',
      calculatedAt: DateTime.utc(2026, 8, 21),
      sampleCount: 20,
    );

    final result = planner.generate(
      settings: TripSettings.initial().copyWith(
        parkId: 'tokyo_disneyland',
        canUseDpa: true,
        wantsBreakfast: false,
        wantsLunch: false,
        wantsDinner: false,
      ),
      facilities: const [facility],
      preferences: [PlanPreference.initial(facilityId: facility.id)],
      waitProfiles: [profile],
      dpaStrategy: const DpaStrategy.disabled(),
    );

    expect(result.dpaFacilityIds, [facility.id]);
    expect(result.preferences.single.accessMethod, FacilityAccessMethod.dpa);
  });

  test('アトラクションDPA最大2個なら高混雑アトラクションを2件まで自動選択する', () {
    const planner = AiDayPlanner();
    const facilities = [
      Facility(
        id: 'dpa_a',
        parkId: 'tokyo_disneyland',
        areaId: 'tdl_test',
        name: 'DPA A',
        category: FacilityCategory.attraction,
        coordinate: Coordinate(latitude: 0, longitude: 0),
        durationMinutes: 10,
        supportsDpa: true,
      ),
      Facility(
        id: 'dpa_b',
        parkId: 'tokyo_disneyland',
        areaId: 'tdl_test',
        name: 'DPA B',
        category: FacilityCategory.attraction,
        coordinate: Coordinate(latitude: 0, longitude: 0),
        durationMinutes: 10,
        supportsDpa: true,
      ),
    ];
    final profiles = facilities
        .map(
          (facility) => TimeBandWaitProfile(
            facilityId: facility.id,
            parkId: facility.parkId,
            ranges: const {
              WaitTimeBand.afterLunch: WaitTimeRange(
                minMinutes: 80,
                typicalMinutes: 90,
                maxMinutes: 100,
                sampleCount: 10,
              ),
              WaitTimeBand.afterOpening: WaitTimeRange(
                minMinutes: 70,
                typicalMinutes: 80,
                maxMinutes: 90,
                sampleCount: 10,
              ),
            },
            source: 'test history',
            calculatedAt: DateTime.utc(2026, 8, 24),
            sampleCount: 20,
          ),
        )
        .toList();

    final result = planner.generate(
      settings: TripSettings.initial().copyWith(
        parkId: 'tokyo_disneyland',
        canUseDpa: true,
        attractionDpaMaxUses: 2,
        wantsBreakfast: false,
        wantsLunch: false,
        wantsDinner: false,
      ),
      facilities: facilities,
      preferences: facilities
          .map((facility) => PlanPreference.initial(facilityId: facility.id))
          .toList(),
      waitProfiles: profiles,
      dpaStrategy: const DpaStrategy.disabled(),
    );

    expect(result.dpaFacilityIds, hasLength(2));
  });

  test('ショーDPAは事前のアトラクションDPA自動配分へ含めない', () {
    const planner = AiDayPlanner();
    const show = Facility(
      id: 'show_dpa',
      parkId: 'tokyo_disneyland',
      areaId: 'tdl_test',
      name: 'DPAショー',
      category: FacilityCategory.show,
      coordinate: Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 20,
      supportsDpa: true,
      requiresEntryRequest: true,
    );
    final profile = TimeBandWaitProfile(
      facilityId: show.id,
      parkId: show.parkId,
      ranges: const {
        WaitTimeBand.afterLunch: WaitTimeRange(
          minMinutes: 100,
          typicalMinutes: 120,
          maxMinutes: 140,
          sampleCount: 10,
        ),
      },
      source: 'test history',
      calculatedAt: DateTime.utc(2026, 8, 24),
      sampleCount: 10,
    );

    final result = planner.generate(
      settings: TripSettings.initial().copyWith(
        parkId: 'tokyo_disneyland',
        attractionDpaMaxUses: 3,
        canUseDpa: true,
        wantsBreakfast: false,
        wantsLunch: false,
        wantsDinner: false,
      ),
      facilities: const [show],
      preferences: [PlanPreference.initial(facilityId: show.id)],
      waitProfiles: [profile],
      dpaStrategy: const DpaStrategy.disabled(),
    );

    expect(result.dpaFacilityIds, isEmpty);
  });

}
