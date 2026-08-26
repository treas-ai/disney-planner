import 'package:disney_planner/domain/entities/day_schedule.dart';
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

Facility _facility(
  String id, {
  String areaId = 'area_a',
  bool supportsPriorityPass = false,
  bool supportsDpa = false,
  bool supportsSingleRider = false,
}) {
  return Facility(
    id: id,
    parkId: 'tokyo_disneyland',
    areaId: areaId,
    name: id,
    category: FacilityCategory.attraction,
    coordinate: const Coordinate(latitude: 0, longitude: 0),
    durationMinutes: 10,
    supportsPriorityPass: supportsPriorityPass,
    supportsDpa: supportsDpa,
    supportsSingleRider: supportsSingleRider,
  );
}

TripSettings _settings({
  bool canUsePriorityPass = false,
  bool canUseSingleRider = false,
}) {
  return TripSettings.initial().copyWith(
    parkId: 'tokyo_disneyland',
    visitDateIso: '2026-08-29T00:00:00.000',
    entryTimeHour: 9,
    entryTimeMinute: 0,
    exitTimeHour: 21,
    exitTimeMinute: 0,
    wantsBreakfast: false,
    wantsLunch: false,
    wantsDinner: false,
    canUseDpa: false,
    canUsePriorityPass: canUsePriorityPass,
    canUseSingleRider: canUseSingleRider,
  );
}

TimeBandWaitProfile _profile(
  Facility facility, {
  required int opening,
  required int beforeLunch,
  required int afterLunch,
}) {
  return TimeBandWaitProfile(
    facilityId: facility.id,
    parkId: facility.parkId,
    ranges: {
      WaitTimeBand.afterOpening: WaitTimeRange(
        minMinutes: opening,
        typicalMinutes: opening,
        maxMinutes: opening,
        sampleCount: 30,
      ),
      WaitTimeBand.beforeLunch: WaitTimeRange(
        minMinutes: beforeLunch,
        typicalMinutes: beforeLunch,
        maxMinutes: beforeLunch,
        sampleCount: 30,
      ),
      WaitTimeBand.afterLunch: WaitTimeRange(
        minMinutes: afterLunch,
        typicalMinutes: afterLunch,
        maxMinutes: afterLunch,
        sampleCount: 30,
      ),
    },
    source: 'opening strategy test',
    calculatedAt: DateTime.utc(2026, 8, 26),
    sampleCount: 90,
  );
}

List<String> _plannedIds(DaySchedule schedule) => schedule.items
    .where((item) => item.facilityId != null)
    .map((item) => item.facilityId!)
    .toList(growable: false);

void main() {
  test('opening strategy prioritizes defer loss over shortest current wait', () {
    final shortestNow = _facility('shortest_now');
    final costlyToDefer = _facility('costly_to_defer');
    final stable = _facility('stable');

    final schedule = const ScheduleEngine().generate(
      settings: _settings(),
      facilities: [shortestNow, costlyToDefer, stable],
      preferences: [
        PlanPreference.initial(facilityId: shortestNow.id),
        PlanPreference.initial(facilityId: costlyToDefer.id),
        PlanPreference.initial(facilityId: stable.id),
      ],
      waitProfiles: [
        _profile(shortestNow, opening: 5, beforeLunch: 10, afterLunch: 10),
        _profile(costlyToDefer, opening: 25, beforeLunch: 90, afterLunch: 100),
        _profile(stable, opening: 20, beforeLunch: 25, afterLunch: 25),
      ],
    );

    final planned = _plannedIds(schedule);
    expect(planned.first, costlyToDefer.id);
    final firstItem = schedule.items.firstWhere(
      (item) => item.facilityId == costlyToDefer.id,
    );
    expect(firstItem.reason, contains('最初の3手'));
    expect(firstItem.reason, contains('後回し損失'));
  });

  test('opening rush is pushed later when its wait improves after opening', () {
    final rush = _facility('opening_rush');
    final opportunity = _facility('opening_opportunity');

    final schedule = const ScheduleEngine().generate(
      settings: _settings(),
      facilities: [rush, opportunity],
      preferences: [
        PlanPreference.initial(facilityId: rush.id),
        PlanPreference.initial(facilityId: opportunity.id),
      ],
      waitProfiles: [
        _profile(rush, opening: 80, beforeLunch: 45, afterLunch: 40),
        _profile(opportunity, opening: 30, beforeLunch: 70, afterLunch: 75),
      ],
    );

    expect(_plannedIds(schedule).first, opportunity.id);
  });

  test('available Priority Pass lowers opening standby necessity', () {
    final passAlternative = _facility(
      'pass_alternative',
      supportsPriorityPass: true,
    );
    final standbyOnly = _facility('standby_only');

    final commonProfiles = [
      _profile(passAlternative, opening: 20, beforeLunch: 60, afterLunch: 70),
      _profile(standbyOnly, opening: 20, beforeLunch: 55, afterLunch: 65),
    ];
    final preferences = [
      PlanPreference.initial(facilityId: passAlternative.id),
      PlanPreference.initial(facilityId: standbyOnly.id),
    ];

    final withoutPass = const ScheduleEngine().generate(
      settings: _settings(canUsePriorityPass: false),
      facilities: [passAlternative, standbyOnly],
      preferences: preferences,
      waitProfiles: commonProfiles,
    );
    final withPass = const ScheduleEngine().generate(
      settings: _settings(canUsePriorityPass: true),
      facilities: [passAlternative, standbyOnly],
      preferences: preferences,
      waitProfiles: commonProfiles,
    );

    expect(_plannedIds(withoutPass).first, passAlternative.id);
    expect(_plannedIds(withPass).first, standbyOnly.id);
  });
}
