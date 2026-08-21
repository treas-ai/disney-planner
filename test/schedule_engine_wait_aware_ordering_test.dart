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

Facility _facility(String id, String name, {int displayOrder = 0}) {
  return Facility(
    id: id,
    parkId: 'tokyo_disneyland',
    areaId: 'tdl_test_area',
    name: name,
    category: FacilityCategory.attraction,
    coordinate: const Coordinate(latitude: 0, longitude: 0),
    durationMinutes: 10,
    displayOrder: displayOrder,
  );
}

TripSettings _settings() {
  return TripSettings.initial().copyWith(
    parkId: 'tokyo_disneyland',
    visitDateIso: '2026-08-21T00:00:00.000',
    entryTimeHour: 9,
    entryTimeMinute: 0,
    exitTimeHour: 21,
    exitTimeMinute: 0,
    wantsBreakfast: false,
    wantsLunch: false,
    wantsDinner: false,
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
        sampleCount: 10,
      ),
      WaitTimeBand.beforeLunch: WaitTimeRange(
        minMinutes: beforeLunch,
        typicalMinutes: beforeLunch,
        maxMinutes: beforeLunch,
        sampleCount: 10,
      ),
      WaitTimeBand.afterLunch: WaitTimeRange(
        minMinutes: afterLunch,
        typicalMinutes: afterLunch,
        maxMinutes: afterLunch,
        sampleCount: 10,
      ),
    },
    source: 'test history',
    calculatedAt: DateTime.utc(2026, 8, 21),
    sampleCount: 30,
  );
}

void main() {
  test('morning-only low wait attraction can overtake route order', () {
    final stable = _facility('stable', '終日安定', displayOrder: 1);
    final morningCritical = _facility(
      'morning_critical',
      '朝一重要',
      displayOrder: 2,
    );

    final schedule = const ScheduleEngine().generate(
      settings: _settings(),
      facilities: [stable, morningCritical],
      preferences: [
        PlanPreference.initial(facilityId: stable.id),
        PlanPreference.initial(facilityId: morningCritical.id),
      ],
      waitProfiles: [
        _profile(stable, opening: 20, beforeLunch: 20, afterLunch: 20),
        _profile(
          morningCritical,
          opening: 20,
          beforeLunch: 80,
          afterLunch: 80,
        ),
      ],
    );

    final planned = schedule.items
        .where((item) => item.facilityId != null)
        .toList(growable: false);

    expect(planned.first.facilityId, morningCritical.id);
    expect(planned.first.reason, contains('この時間帯を逃すと'));
  });

  test('multiple morning-sensitive attractions compete by delay penalty', () {
    final a = _facility('a', '朝一A', displayOrder: 1);
    final b = _facility('b', '朝一B', displayOrder: 2);
    final c = _facility('c', '後回し可能', displayOrder: 3);

    final schedule = const ScheduleEngine().generate(
      settings: _settings(),
      facilities: [a, b, c],
      preferences: [
        PlanPreference.initial(facilityId: a.id),
        PlanPreference.initial(facilityId: b.id),
        PlanPreference.initial(facilityId: c.id),
      ],
      waitProfiles: [
        _profile(a, opening: 20, beforeLunch: 70, afterLunch: 70),
        _profile(b, opening: 30, beforeLunch: 100, afterLunch: 100),
        _profile(c, opening: 50, beforeLunch: 30, afterLunch: 20),
      ],
    );

    final planned = schedule.items
        .where((item) => item.facilityId != null)
        .toList(growable: false);

    expect(planned[0].facilityId, b.id);
    expect(planned[1].facilityId, a.id);
    expect(planned.last.facilityId, c.id);
  });

  test('thin time-band samples do not reorder the day', () {
    final first = _facility('first', '既存順1', displayOrder: 1);
    final thin = _facility('thin', '薄い朝一データ', displayOrder: 2);

    final thinProfile = TimeBandWaitProfile(
      facilityId: thin.id,
      parkId: thin.parkId,
      ranges: const {
        WaitTimeBand.afterOpening: WaitTimeRange(
          minMinutes: 10,
          typicalMinutes: 10,
          maxMinutes: 10,
          sampleCount: 2,
        ),
        WaitTimeBand.beforeLunch: WaitTimeRange(
          minMinutes: 100,
          typicalMinutes: 100,
          maxMinutes: 100,
          sampleCount: 2,
        ),
      },
      source: 'thin test',
      calculatedAt: DateTime.utc(2026, 8, 21),
      sampleCount: 4,
    );

    final schedule = const ScheduleEngine().generate(
      settings: _settings(),
      facilities: [first, thin],
      preferences: [
        PlanPreference.initial(facilityId: first.id),
        PlanPreference.initial(facilityId: thin.id),
      ],
      waitProfiles: [
        _profile(first, opening: 20, beforeLunch: 20, afterLunch: 20),
        thinProfile,
      ],
    );

    final planned = schedule.items
        .where((item) => item.facilityId != null)
        .toList(growable: false);

    expect(planned.first.facilityId, first.id);
  });

  test('later closing dip does not hide a costly morning wait increase', () {
    final stable = _facility('stable_late_dip', '終日ほぼ安定', displayOrder: 1);
    final morningCritical = _facility(
      'morning_critical_late_dip',
      '昼に急増して夜に下がる施設',
      displayOrder: 2,
    );

    TimeBandWaitProfile fullProfile(
      Facility facility,
      List<int> waits,
    ) {
      final bands = <WaitTimeBand>[
        WaitTimeBand.afterOpening,
        WaitTimeBand.beforeLunch,
        WaitTimeBand.afterLunch,
        WaitTimeBand.aroundShows,
        WaitTimeBand.beforeDinner,
        WaitTimeBand.afterDinner,
        WaitTimeBand.beforeClosing,
      ];
      return TimeBandWaitProfile(
        facilityId: facility.id,
        parkId: facility.parkId,
        ranges: {
          for (var i = 0; i < bands.length; i++)
            bands[i]: WaitTimeRange(
              minMinutes: waits[i],
              typicalMinutes: waits[i],
              maxMinutes: waits[i],
              sampleCount: 10,
            ),
        },
        source: 'test history',
        calculatedAt: DateTime.utc(2026, 8, 21),
        sampleCount: 70,
      );
    }

    final schedule = const ScheduleEngine().generate(
      settings: _settings(),
      facilities: [stable, morningCritical],
      preferences: [
        PlanPreference.initial(facilityId: stable.id),
        PlanPreference.initial(facilityId: morningCritical.id),
      ],
      waitProfiles: [
        fullProfile(stable, [20, 25, 25, 25, 25, 20, 15]),
        // Cheap at opening, expensive around lunch, cheap again at closing.
        fullProfile(morningCritical, [30, 70, 80, 75, 65, 50, 20]),
      ],
    );

    final planned = schedule.items
        .where((item) => item.facilityId != null)
        .toList(growable: false);

    expect(planned.first.facilityId, morningCritical.id);
    expect(planned.first.reason, contains('この時間帯を逃すと'));
  });


}
