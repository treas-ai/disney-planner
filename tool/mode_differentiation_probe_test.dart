import 'package:disney_planner/domain/entities/area_connection.dart';
import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/facility_location.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/time_band_wait_profile.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/entities/wait_time_range.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/wait_time_band.dart';
import 'package:disney_planner/domain/services/plan_quality_audit_service.dart';
import 'package:disney_planner/domain/services/schedule_engine.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

Facility facility(String id, String area, int order) => Facility(
  id: id,
  parkId: 'tokyo_disneyland',
  areaId: area,
  name: id,
  category: FacilityCategory.attraction,
  coordinate: const Coordinate(latitude: 0, longitude: 0),
  durationMinutes: 10,
  displayOrder: order,
);

TimeBandWaitProfile profile(Facility f, List<int> waits) {
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
    facilityId: f.id,
    parkId: f.parkId,
    ranges: {
      for (var i = 0; i < bands.length; i++)
        bands[i]: WaitTimeRange(
          minMinutes: waits[i],
          typicalMinutes: waits[i],
          maxMinutes: waits[i],
          sampleCount: 20,
        ),
    },
    source: 'mode differentiation probe',
    calculatedAt: DateTime.utc(2026, 10, 5),
    sampleCount: 140,
  );
}

void main() {
  test('print four-mode differentiation metrics without changing production scoring', () {
    final facilities = <Facility>[
      facility('east_a', 'east', 1),
      facility('west_a', 'west', 2),
      facility('east_b', 'east', 3),
      facility('north_a', 'north', 4),
      facility('west_b', 'west', 5),
      facility('north_b', 'north', 6),
    ];
    final waits = <String, List<int>>{
      'east_a': [15, 35, 45, 40, 35, 25, 20],
      'west_a': [20, 20, 25, 30, 35, 35, 30],
      'east_b': [30, 25, 20, 20, 25, 30, 35],
      'north_a': [35, 30, 25, 20, 20, 25, 30],
      'west_b': [40, 35, 30, 25, 20, 15, 15],
      'north_b': [25, 30, 35, 35, 30, 25, 20],
    };
    const connections = <AreaConnection>[
      AreaConnection(parkId: 'tokyo_disneyland', fromAreaId: 'east', toAreaId: 'west', minutes: 22),
      AreaConnection(parkId: 'tokyo_disneyland', fromAreaId: 'west', toAreaId: 'north', minutes: 18),
      AreaConnection(parkId: 'tokyo_disneyland', fromAreaId: 'east', toAreaId: 'north', minutes: 12),
    ];
    final locations = <FacilityLocation>[
      for (var i = 0; i < facilities.length; i++)
        FacilityLocation(
          parkId: 'tokyo_disneyland',
          facilityId: facilities[i].id,
          areaId: facilities[i].areaId,
          x: i.toDouble(),
          y: 0,
        ),
    ];
    final base = TripSettings.initial().copyWith(
      parkId: 'tokyo_disneyland',
      visitDateIso: '2026-10-05T00:00:00.000',
      entryTimeHour: 9,
      entryTimeMinute: 0,
      exitTimeHour: 21,
      exitTimeMinute: 0,
      wantsBreakfast: false,
      wantsLunch: false,
      wantsDinner: false,
    );
    final prefs = [for (final f in facilities) PlanPreference.initial(facilityId: f.id)];
    final profiles = [for (final f in facilities) profile(f, waits[f.id]!)];
    const audit = PlanQualityAuditService();
    final signatures = <String>{};

    for (final mode in ScheduleOptimizationMode.values) {
      final schedule = const ScheduleEngine().generate(
        settings: base.copyWith(scheduleOptimizationMode: mode),
        facilities: facilities,
        preferences: prefs,
        waitProfiles: profiles,
        areaConnections: connections,
        facilityLocations: locations,
      );
      final quality = audit.evaluate(
        schedule,
        facilities: facilities,
        facilityLocations: locations,
        areaConnections: connections,
      );
      final ordered = schedule.items
          .where((item) => item.facilityId != null)
          .map((item) => item.facilityId!)
          .toList(growable: false);
      expect(ordered.toSet().length, facilities.length,
          reason: '$mode must preserve all probe wishes');
      expect(quality.overlapCount, 0, reason: '$mode must remain feasible');
      final signature = ordered.join('>');
      signatures.add(signature);
      // ignore: avoid_print
      print('MODE_PROBE ${mode.name} wait=${quality.totalWaitMinutes} '
          'move=${quality.totalMovementMinutes} crossings=${quality.areaCrossingCount} '
          'revisits=${quality.areaRevisitCount} free=${quality.totalFreeMinutes} '
          'blocks=${quality.freeBlockCount} largest=${quality.largestFreeBlockMinutes} '
          'small=${quality.smallFreeBlockCount} order=$signature');
    }

    // This probe is intentionally non-blocking for differentiation. Equality is
    // a diagnostic result, not a reason to break the normal regression suite.
    // ignore: avoid_print
    print('MODE_PROBE distinct_orders=${signatures.length}/4');
  });
}
