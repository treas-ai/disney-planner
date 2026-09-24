import 'package:flutter/foundation.dart';

import '../../domain/entities/day_schedule.dart';
import '../../domain/entities/trip_settings.dart';
import '../../domain/entities/today_access_result.dart';
import '../../domain/enums/facility_access_method.dart';
import '../../domain/enums/today_access_kind.dart';
import '../../domain/enums/today_access_status.dart';
import '../constants/app_version.dart';

enum DebugAnalysisStatus { pass, fail, check }

enum DebugAnalysisContext { preTrip, today }

class DebugAnalysisReport {
  const DebugAnalysisReport({required this.text, required this.result});
  final String text;
  final DebugAnalysisStatus result;
}

/// AI-facing debug snapshot. This is diagnostic only and must never drive
/// production planning behavior.
abstract final class DebugAnalysisReporter {
  static String get debugId => '${AppVersion.displayName} four-mode-diagnostics';

  static DebugAnalysisReport build({
    required TripSettings settings,
    required DaySchedule schedule,
    required List<TodayAccessResult> todayAccessResults,
    required int desiredOccurrenceCount,
    required int achievedOccurrenceCount,
    DebugAnalysisContext context = DebugAnalysisContext.preTrip,
    List<String> unachievedWishLabels = const <String>[],
    List<String> unachievedHardWishLabels = const <String>[],
    List<String> unachievedOptionalWishLabels = const <String>[],
    int? totalFreeMinutes,
    String? fourModeGateReport,
  }) {
    final acquiredDpa = todayAccessResults.where((result) =>
        (result.kind == TodayAccessKind.attractionDpa ||
            result.kind == TodayAccessKind.showDpa) &&
        (result.status == TodayAccessStatus.acquired ||
            result.status == TodayAccessStatus.won));
    final acquiredIds = acquiredDpa.map((e) => e.facilityId).toSet();
    final scheduledDpa = schedule.items.where(
      (item) => item.accessMethod == FacilityAccessMethod.dpa,
    ).toList(growable: false);
    final unacquiredScheduledDpa = scheduledDpa.where(
      (item) => item.facilityId == null || !acquiredIds.contains(item.facilityId),
    ).toList(growable: false);
    final acquiredDpaWithTime = acquiredDpa
        .where((result) => result.fixesTime)
        .toList(growable: false);
    final acquiredDpaScheduleMismatches = <String>[];
    for (final result in acquiredDpaWithTime) {
      final matches = scheduledDpa.where((item) =>
          item.facilityId == result.facilityId &&
          item.startTimeLabel == result.time);
      if (matches.isEmpty) {
        acquiredDpaScheduleMismatches.add(
          '${result.facilityId} acquired=${result.time}',
        );
      }
    }

    final checks = <(String, DebugAnalysisStatus, String)>[
      ('Version source', DebugAnalysisStatus.pass, AppVersion.displayName),
      (
        'DPA purchase candidates stored',
        DebugAnalysisStatus.pass,
        settings.plannedDpaFacilityIds.isEmpty
            ? 'none (valid)'
            : settings.plannedDpaFacilityIds.join(', '),
      ),
      (
        'Acquired DPA state readable',
        DebugAnalysisStatus.pass,
        '${acquiredIds.length}',
      ),
      (
        'No unacquired DPA scheduled',
        unacquiredScheduledDpa.isEmpty
            ? DebugAnalysisStatus.pass
            : DebugAnalysisStatus.fail,
        unacquiredScheduledDpa.isEmpty
            ? '0'
            : unacquiredScheduledDpa
                .map((item) => '${item.title} ${item.startTimeLabel}')
                .join(' / '),
      ),
      if (context == DebugAnalysisContext.today)
        (
          'Acquired DPA time is authoritative',
          acquiredDpaScheduleMismatches.isEmpty
              ? DebugAnalysisStatus.pass
              : DebugAnalysisStatus.fail,
          acquiredDpaWithTime.isEmpty
              ? 'no acquired DPA with fixed time'
              : acquiredDpaScheduleMismatches.isEmpty
                  ? acquiredDpaWithTime
                      .map((result) => '${result.facilityId} ${result.time}')
                      .join(' / ')
                  : acquiredDpaScheduleMismatches.join(' / '),
        )
      else
        (
          'Today acquired DPA scope',
          DebugAnalysisStatus.pass,
          acquiredDpaWithTime.isEmpty
              ? 'none; PRE-TRIP validation unaffected'
              : 'PRE-TRIP: ${acquiredDpaWithTime.length} Today acquired DPA result(s) are intentionally not matched against this schedule',
        ),
      (
        'Four optimization modes runtime comparison',
        fourModeGateReport?.contains('RESULT: PASS') == true
            ? DebugAnalysisStatus.pass
            : fourModeGateReport?.contains('RESULT: FAIL') == true
                ? DebugAnalysisStatus.fail
                : DebugAnalysisStatus.check,
        fourModeGateReport == null
            ? 'requires explicit 4-mode run'
            : fourModeGateReport.contains('RESULT: PASS')
                ? 'automated debug gate passed'
                : fourModeGateReport.contains('RESULT: FAIL')
                    ? 'automated debug gate failed'
                    : 'automated debug gate remains CHECK',
      ),
      (
        'Runtime platform',
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
            ? DebugAnalysisStatus.pass
            : DebugAnalysisStatus.check,
        kIsWeb
            ? 'web'
            : defaultTargetPlatform == TargetPlatform.windows
                ? 'Windows'
                : defaultTargetPlatform.name,
      ),
      (
        'Windows full runtime gate',
        DebugAnalysisStatus.check,
        'requires explicit end-to-end runtime confirmation',
      ),
    ];

    final result = checks.any((e) => e.$2 == DebugAnalysisStatus.fail)
        ? DebugAnalysisStatus.fail
        : checks.any((e) => e.$2 == DebugAnalysisStatus.check)
            ? DebugAnalysisStatus.check
            : DebugAnalysisStatus.pass;

    String status(DebugAnalysisStatus value) => switch (value) {
          DebugAnalysisStatus.pass => 'PASS',
          DebugAnalysisStatus.fail => 'FAIL',
          DebugAnalysisStatus.check => 'CHECK',
        };

    final buffer = StringBuffer()
      ..writeln()
      ..writeln('===== Disney Planner DEBUG ANALYSIS =====')
      ..writeln('【ビルド情報】')
      ..writeln('Version: ${AppVersion.displayName}')
      ..writeln('Build number: ${AppVersion.buildNumber}')
      ..writeln('Debug ID: $debugId')
      ..writeln('Build mode: DEBUG')
      ..writeln('Context: ${context == DebugAnalysisContext.preTrip ? 'PRE-TRIP' : 'TODAY'}')
      ..writeln()
      ..writeln('【実装機能】')
      ..writeln('Wishes 2.0: ENABLED')
      ..writeln('Intentional Free Time: ENABLED')
      ..writeln('Conditional Wishes: ENABLED')
      ..writeln('DPA Scenario Comparison: ENABLED')
      ..writeln('Pre-trip DPA Candidate: ENABLED')
      ..writeln('Acquired DPA Scheduling: ENABLED (Today input path)')
      ..writeln('VP Comparison: NOT IMPLEMENTED')
      ..writeln()
      ..writeln('【現在の設定】')
      ..writeln('Park: ${settings.parkId}')
      ..writeln('Date: ${settings.visitDateIso.isEmpty ? 'not set' : settings.visitDateIso}')
      ..writeln('Optimization: ${settings.scheduleOptimizationMode.name}')
      ..writeln('DPA max: ${settings.attractionDpaMaxUses}')
      ..writeln('Budget mode: ${settings.planningBudgetMode.name}')
      ..writeln('Planned DPA IDs: ${settings.plannedDpaFacilityIds.isEmpty ? 'none' : settings.plannedDpaFacilityIds.join(', ')}')
      ..writeln('Acquired DPA IDs: ${acquiredIds.isEmpty ? 'none' : acquiredIds.join(', ')}')
      ..writeln('Acquired DPA fixed times: ${acquiredDpaWithTime.isEmpty ? 'none' : acquiredDpaWithTime.map((result) => '${result.facilityId}=${result.time}').join(', ')}')
      ..writeln()
      ..writeln('【プラン内部状態】')
      ..writeln('Desired occurrences: $desiredOccurrenceCount')
      ..writeln('Achieved occurrences: $achievedOccurrenceCount')
      ..writeln('Scheduled DPA: ${scheduledDpa.length}')
      ..writeln('Planned DPA: ${settings.plannedDpaFacilityIds.length}')
      ..writeln('Acquired DPA: ${acquiredIds.length}')
      ..writeln('Unachieved wishes: ${unachievedWishLabels.isEmpty ? 'none' : unachievedWishLabels.join(' / ')}')
      ..writeln('Unachieved hard wishes: ${unachievedHardWishLabels.isEmpty ? 'none' : unachievedHardWishLabels.join(' / ')}')
      ..writeln('Unachieved optional wishes: ${unachievedOptionalWishLabels.isEmpty ? 'none' : unachievedOptionalWishLabels.join(' / ')}')
      ..writeln('Total free minutes: ${totalFreeMinutes ?? 'not available'}')
      ..writeln()
      ..writeln('【整合性チェック】');
    for (final check in checks) {
      buffer.writeln('[${status(check.$2)}] ${check.$1} — ${check.$3}');
    }
    buffer
      ..writeln()
      ..writeln('【診断結果】')
      ..writeln('RESULT: ${status(result)}');
    final pendingChecks = checks.where((e) => e.$2 == DebugAnalysisStatus.check).toList(growable: false);
    if (pendingChecks.isNotEmpty) {
      buffer.writeln('Pending:');
      for (final check in pendingChecks) {
        buffer.writeln('- ${check.$1}: ${check.$3}');
      }
    }
    final missingCount = desiredOccurrenceCount - achievedOccurrenceCount;
    final hasHardRegression = unachievedHardWishLabels.isNotEmpty;
    if (missingCount > 0 || (totalFreeMinutes != null && totalFreeMinutes >= 120)) {
      buffer.writeln('Regression watch:');
      if (hasHardRegression) {
        buffer.writeln('[WARN] Hard wish coverage — ${unachievedHardWishLabels.length} occurrence(s) unachieved');
        buffer.writeln('[WARN] Unachieved hard wishes: ${unachievedHardWishLabels.join(' / ')}');
      } else {
        buffer.writeln('[PASS] Hard wish coverage — all required occurrences achieved');
      }
      if (unachievedOptionalWishLabels.isNotEmpty) {
        buffer.writeln('[INFO] Optional wishes unachieved: ${unachievedOptionalWishLabels.length}');
        buffer.writeln('[INFO] Unachieved optional wishes: ${unachievedOptionalWishLabels.join(' / ')}');
      } else if (missingCount == 0) {
        buffer.writeln('[PASS] Optional wish coverage — no unachieved optional occurrences');
      }
      if (hasHardRegression && totalFreeMinutes != null && totalFreeMinutes >= 120) {
        buffer.writeln('[WARN] Free time: $totalFreeMinutes min despite ${unachievedHardWishLabels.length} unachieved hard occurrences');
        buffer.writeln('AI investigation hint: hard wish が optional/conditional wish の制約に巻き込まれていないか、Beam Search の必須カバレッジを確認してください。');
      }
    }
    if (unacquiredScheduledDpa.isNotEmpty) {
      buffer
        ..writeln('Problem: 未取得DPAが実スケジュールでDPA利用になっています。')
        ..writeln('AI investigation hint: plannedDpaFacilityIds と ScheduleItem.accessMethod の生成経路を確認してください。');
    }
    if (acquiredDpaScheduleMismatches.isNotEmpty) {
      buffer
        ..writeln('Problem: 取得済みDPAの実時間と実スケジュールが一致していません。')
        ..writeln('AI investigation hint: TodayAccessResult.time を authoritative fixed time として effectivePlanPreferencesForToday / ScheduleRecalculationService へ伝播しているか確認してください。');
    }
    buffer.writeln('===== END DEBUG ANALYSIS =====');
    return DebugAnalysisReport(text: buffer.toString().trimRight(), result: result);
  }
}
