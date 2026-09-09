import 'package:disney_planner/domain/entities/day_schedule.dart';
import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/facility_location.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/time_band_wait_profile.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/entities/wait_time_range.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/wait_time_band.dart';
import 'package:disney_planner/domain/services/schedule_engine.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:disney_planner/domain/value_objects/operating_hours.dart';
import 'package:flutter_test/flutter_test.dart';

Facility _facility(
  String id, {
  String areaId = 'area_a',
  String parkId = 'tokyo_disneyland',
  bool supportsPriorityPass = false,
  bool supportsDpa = false,
  bool supportsSingleRider = false,
  String? rideType,
  OperatingHours? operatingHours,
}) {
  return Facility(
    id: id,
    parkId: parkId,
    areaId: areaId,
    name: id,
    category: FacilityCategory.attraction,
    coordinate: const Coordinate(latitude: 0, longitude: 0),
    durationMinutes: 10,
    operatingHours: operatingHours,
    supportsPriorityPass: supportsPriorityPass,
    supportsDpa: supportsDpa,
    supportsSingleRider: supportsSingleRider,
    rideType: rideType,
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
    expect(firstItem.reason, contains('移動5分'));
    expect(firstItem.reason, contains('候補評価時点では待ち'));
  });

  test('opening explanation is removed when operating hours push item out of morning', () {
    final delayedStrategic = _facility(
      'delayed_strategic',
      operatingHours: OperatingHours(
        open: DateTime(2026, 8, 29, 12, 30),
        close: DateTime(2026, 8, 29, 21),
      ),
    );
    final filler = _facility('filler');

    final schedule = const ScheduleEngine().generate(
      settings: _settings(),
      facilities: [delayedStrategic, filler],
      preferences: [
        PlanPreference.initial(facilityId: delayedStrategic.id),
        PlanPreference.initial(facilityId: filler.id),
      ],
      waitProfiles: [
        _profile(
          delayedStrategic,
          opening: 10,
          beforeLunch: 90,
          afterLunch: 100,
        ),
        _profile(filler, opening: 20, beforeLunch: 20, afterLunch: 20),
      ],
    );

    final item = schedule.items.firstWhere(
      (item) => item.facilityId == delayedStrategic.id,
    );
    expect(item.startHour, 12);
    expect(item.startMinute, 30);
    expect(item.reason, isNot(contains('朝一は')));
    expect(item.reason, isNot(contains('候補評価時点では待ち')));
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

  test('opening strategy favors all-day difficult attraction over short-wait transport', () {
    final transport = _facility(
      'transport',
      areaId: 'area_a',
      rideType: 'transportation',
    );
    final strategic = _facility(
      'strategic',
      areaId: 'area_a',
    );
    final filler = _facility('filler', areaId: 'area_a');

    final schedule = const ScheduleEngine().generate(
      settings: _settings(),
      facilities: [transport, strategic, filler],
      preferences: [
        PlanPreference.initial(facilityId: transport.id),
        PlanPreference.initial(facilityId: strategic.id),
        PlanPreference.initial(facilityId: filler.id),
      ],
      waitProfiles: [
        _profile(transport, opening: 5, beforeLunch: 20, afterLunch: 25),
        _profile(strategic, opening: 30, beforeLunch: 80, afterLunch: 100),
        _profile(filler, opening: 10, beforeLunch: 15, afterLunch: 20),
      ],
    );

    expect(_plannedIds(schedule).first, strategic.id);
    final firstItem = schedule.items.firstWhere(
      (item) => item.facilityId == strategic.id,
    );
    expect(firstItem.reason, contains('通常待機難易度'));
  });

  test('ambiguous transport destination is penalized more strongly at opening', () {
    final ambiguousTransport = _facility(
      'ambiguous_transport',
      areaId: 'area_a',
      rideType: 'transportation',
    );
    final fixedTransport = _facility(
      'fixed_transport',
      areaId: 'area_a',
      rideType: 'transportation',
    );
    final stable = _facility('stable', areaId: 'area_a');

    final schedule = const ScheduleEngine().generate(
      settings: _settings(),
      facilities: [ambiguousTransport, fixedTransport, stable],
      preferences: [
        PlanPreference.initial(facilityId: ambiguousTransport.id),
        PlanPreference.initial(facilityId: fixedTransport.id),
        PlanPreference.initial(facilityId: stable.id),
      ],
      waitProfiles: [
        _profile(ambiguousTransport, opening: 5, beforeLunch: 35, afterLunch: 35),
        _profile(fixedTransport, opening: 5, beforeLunch: 35, afterLunch: 35),
        _profile(stable, opening: 15, beforeLunch: 25, afterLunch: 25),
      ],
      facilityLocations: const [
        FacilityLocation(
          parkId: 'tokyo_disneyland',
          facilityId: 'ambiguous_transport',
          areaId: 'area_a',
          possibleExitAreaIds: ['area_b', 'area_c'],
          x: 0,
          y: 0,
        ),
        FacilityLocation(
          parkId: 'tokyo_disneyland',
          facilityId: 'fixed_transport',
          areaId: 'area_a',
          exitAreaId: 'area_b',
          x: 0,
          y: 0,
        ),
      ],
    );

    expect(_plannedIds(schedule).first, isNot(ambiguousTransport.id));
  });

}
