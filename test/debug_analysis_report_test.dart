import 'package:flutter_test/flutter_test.dart';
import 'package:disney_planner/core/constants/app_version.dart';
import 'package:disney_planner/core/debug/debug_analysis_report.dart';
import 'package:disney_planner/domain/entities/day_schedule.dart';
import 'package:disney_planner/domain/entities/schedule_item.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/facility_access_method.dart';
import 'package:disney_planner/domain/enums/schedule_item_type.dart';

void main() {
  test('debug analysis detects unacquired DPA in schedule', () {
    final settings = TripSettings.initial().copyWith(
      plannedDpaFacilityIds: const ['beauty'],
    );
    final schedule = DaySchedule(
      id: 'debug',
      parkId: 'tokyo_disneyland',
      createdAt: DateTime(2026, 9, 22),
      items: [
        ScheduleItem(
          id: 'x', title: 'Beauty', type: ScheduleItemType.facility,
          startHour: 9, startMinute: 15, endHour: 9, endMinute: 33,
          facilityId: 'beauty', accessMethod: FacilityAccessMethod.dpa,
        ),
      ],
    );
    final report = DebugAnalysisReporter.build(
      settings: settings,
      schedule: schedule,
      todayAccessResults: const [],
      desiredOccurrenceCount: 11,
      achievedOccurrenceCount: 10,
    );
    expect(report.result, DebugAnalysisStatus.fail);
    expect(report.text, contains('[FAIL] No unacquired DPA scheduled'));
    expect(report.text, contains('Version: ${AppVersion.displayName}'));
    expect(report.text, contains('Build number: ${AppVersion.buildNumber}'));
  });

  test('debug analysis separates hard and optional unachieved wishes', () {
    final report = DebugAnalysisReporter.build(
      settings: TripSettings.initial(),
      schedule: DaySchedule(
        id: 'debug_wishes',
        parkId: 'tokyo_disneyland',
        createdAt: DateTime(2026, 9, 22),
        items: const [],
      ),
      todayAccessResults: const [],
      desiredOccurrenceCount: 3,
      achievedOccurrenceCount: 0,
      unachievedWishLabels: const ['Splash', 'Baymax', 'Baymax #2'],
      unachievedHardWishLabels: const ['Splash'],
      unachievedOptionalWishLabels: const ['Baymax', 'Baymax #2'],
      totalFreeMinutes: 232,
    );
    expect(report.text, contains('Unachieved hard wishes: Splash'));
    expect(report.text, contains('Unachieved optional wishes: Baymax / Baymax #2'));
    expect(report.text, contains('[WARN] Free time: 232 min despite 1 unachieved hard occurrences'));
  });


  test('debug analysis consumes automated four-mode gate result', () {
    final report = DebugAnalysisReporter.build(
      settings: TripSettings.initial(),
      schedule: DaySchedule(
        id: 'four_mode',
        parkId: 'tokyo_disneyland',
        createdAt: DateTime(2026, 9, 23),
        items: const [],
      ),
      todayAccessResults: const [],
      desiredOccurrenceCount: 0,
      achievedOccurrenceCount: 0,
      fourModeGateReport: '===== DEBUG 4-MODE GATE =====\nRESULT: PASS\n===== END DEBUG 4-MODE GATE =====',
    );
    expect(
      report.text,
      contains('[PASS] Four optimization modes runtime comparison — automated debug gate passed'),
    );
  });

}
