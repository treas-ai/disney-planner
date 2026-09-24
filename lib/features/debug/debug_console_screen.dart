import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/state/app_state.dart';
import '../../app/state/app_state_scope.dart';
import '../../core/constants/app_version.dart';
import '../../core/debug/debug_gate_registry.dart';
import '../../core/widgets/app_card.dart';
import '../../domain/enums/today_access_kind.dart';
import '../../domain/enums/today_access_status.dart';
import '../../domain/enums/schedule_item_type.dart';
import '../../domain/entities/today_execution_record.dart';
import '../live/live_controller.dart';
import '../plan_review/schedule_controller.dart';
import '../today/schedule_recalculation_controller.dart';

class DebugConsoleScreen extends StatefulWidget {
  const DebugConsoleScreen({super.key});
  @override State<DebugConsoleScreen> createState() => _DebugConsoleScreenState();
}

class _DebugConsoleScreenState extends State<DebugConsoleScreen> {
  AppState? _appState;
  ScheduleController? _controller;
  bool _expanded = true;
  bool _isRunningUnifiedGate = false;
  String? _preTripQualitySnapshot;
  String? _orchestrationReport;

  @override void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    if (identical(_appState, state)) return;
    _controller?.removeListener(_refresh);
    _controller?.dispose();
    _appState = state;
    _controller = ScheduleController(state)..addListener(_refresh);
  }

  @override void dispose() {
    _controller?.removeListener(_refresh);
    _controller?.dispose();
    super.dispose();
  }

  void _refresh() { if (mounted) setState(() {}); }

  String _result(String? s) => s == null
      ? 'CHECK'
      : s.contains('RESULT: FAIL')
          ? 'FAIL'
          : s.contains('RESULT: PASS')
              ? 'PASS'
              : 'CHECK';

  String _qualityText(ScheduleController controller) {
    final audit = controller.planQualityAudit;
    if (audit == null) return 'not available';
    return 'Wait: ${audit.totalWaitMinutes} min\n'
        'Movement: ${audit.totalMovementMinutes} min\n'
        'Free: ${audit.totalFreeMinutes} min\n'
        'Largest free block: ${audit.largestFreeBlockMinutes} min\n'
        'Free blocks: ${audit.freeBlockCount}\n'
        'Overlaps: ${audit.overlapCount}';
  }

  DateTime _debugTodayNow(AppState state) {
    final visit = state.tripSettings.visitDate ?? DateTime.now();
    // 13:30 is deterministic and keeps the representative 14:00 acquired DPA
    // in the future. This is a DEBUG simulation clock, never production state.
    return DateTime(visit.year, visit.month, visit.day, 13, 30);
  }

  Future<String> _runTodaySelfCheck() async {
    final state = _appState!;
    if (state.daySchedule == null) {
      return '[CHECK] Today self-check — no current schedule';
    }
    final live = LiveController(state);
    final recalculation = ScheduleRecalculationController(state, live);
    try {
      live.startSimulation(simulatedNow: _debugTodayNow(state));
      final hasFixedAcquiredDpa = state.todayAccessResults.any((result) =>
          result.kind == TodayAccessKind.attractionDpa &&
          result.status == TodayAccessStatus.acquired &&
          result.fixesTime);
      final proposal = await recalculation.createProposal(
        verificationAction: hasFixedAcquiredDpa ? 'acquired-dpa' : 'recalculate',
        verificationDetail: 'Debug Mode self-contained comprehensive gate',
      );
      if (proposal == null) {
        return '[CHECK] Today self-check — proposal could not be generated';
      }
      recalculation.applyProposal();
      recalculation.undoLastApply();
      return recalculation.verificationReport ??
          '[CHECK] Today self-check — verification report unavailable';
    } catch (error) {
      return '[CHECK] Today self-check — ${error.runtimeType}: $error';
    } finally {
      recalculation.dispose();
      live.dispose();
    }
  }


  Future<String> _runPhaseFExecutionStatusSelfCheck() async {
    final state = _appState!;
    final original = state.daySchedule;
    if (original == null) {
      return '===== PHASE F EXECUTION STATUS GATE =====\n'
          '[CHECK] Current Today schedule is unavailable\n'
          'RESULT: CHECK\n'
          '===== END PHASE F EXECUTION STATUS GATE =====';
    }

    final now = _debugTodayNow(state);
    final fixedDpa = state.todayAccessResults.where((result) =>
        result.kind == TodayAccessKind.attractionDpa &&
        result.status == TodayAccessStatus.acquired &&
        result.fixesTime).toList(growable: false);
    final fixedDpaIds = fixedDpa.map((result) => result.facilityId).toSet();
    final facilityCounts = <String, int>{};
    for (final item in original.items) {
      final id = item.facilityId;
      if (id != null) facilityCounts[id] = (facilityCounts[id] ?? 0) + 1;
    }
    final nowMinutes = now.hour * 60 + now.minute;
    final candidates = original.items.where((item) {
      final id = item.facilityId;
      if (id == null || fixedDpaIds.contains(id)) return false;
      if (facilityCounts[id] != 1) return false;
      return item.startHour * 60 + item.startMinute >= nowMinutes;
    }).toList(growable: false);
    if (candidates.isEmpty) {
      return '===== PHASE F EXECUTION STATUS GATE =====\n'
          '[CHECK] No unique future facility occurrence is available for the self-check\n'
          'RESULT: CHECK\n'
          '===== END PHASE F EXECUTION STATUS GATE =====';
    }
    final target = candidates.first;
    final lines = <String>[
      '===== PHASE F EXECUTION STATUS GATE =====',
      'Target: ${target.title} (${target.facilityId})',
    ];
    var hasFail = false;
    var hasCheck = false;

    Future<void> runCase(TodayExecutionStatus status) async {
      final live = LiveController(state);
      final recalculation = ScheduleRecalculationController(state, live);
      final label = status == TodayExecutionStatus.completed ? 'Completed' : 'Skipped';
      try {
        live.startSimulation(simulatedNow: now);
        live.recordExecution(TodayExecutionRecord(
          scheduleItemId: target.id,
          facilityId: target.facilityId,
          status: status,
          recordedAt: now,
        ));
        final recorded = live.executionRecordFor(target.id)?.status == status;
        final proposal = await recalculation.createProposal(
          verificationAction: 'phase-f-${status.name}',
          verificationDetail: 'Debug Mode Phase F execution-status self-check',
        );
        if (proposal == null) {
          lines.add('[CHECK] $label — proposal could not be generated');
          hasCheck = true;
          return;
        }
        recalculation.applyProposal();
        final after = live.schedule;
        if (after == null) {
          lines.add('[FAIL] $label — applied schedule is unavailable');
          hasFail = true;
          return;
        }
        final reinserted = after.items.any((item) => item.facilityId == target.facilityId);
        final overlapFree = _debugOverlapCount(after.items) == 0;
        final fixedDpaMaintained = fixedDpa.every((result) => after.items.any((item) =>
            item.facilityId == result.facilityId &&
            item.accessMethod?.name == 'dpa' &&
            item.startTimeLabel == result.time));
        recalculation.undoLastApply();
        final undoRestored = _debugSameSchedule(live.schedule, original);
        final recordHeld = live.executionRecordFor(target.id)?.status == status;

        void gate(String name, bool ok) {
          lines.add('[${ok ? 'PASS' : 'FAIL'}] $label — $name');
          if (!ok) hasFail = true;
        }
        gate('execution record stored', recorded);
        gate('executed facility not reinserted', !reinserted);
        gate('execution record retained through replan/Undo', recordHeld);
        gate('fixed acquired DPA maintained', fixedDpaMaintained);
        gate('no overlaps after replan', overlapFree);
        gate('Undo restored schedule', undoRestored);
      } catch (error) {
        lines.add('[FAIL] $label — ${error.runtimeType}: $error');
        hasFail = true;
      } finally {
        recalculation.dispose();
        live.dispose();
        state.debugReplaceDayScheduleWithoutHistory(original);
      }
    }

    await runCase(TodayExecutionStatus.completed);
    await runCase(TodayExecutionStatus.skipped);

    final timingCandidates = candidates.where((item) {
      final end = item.endHour * 60 + item.endMinute;
      return end + 10 < state.tripSettings.exitTimeHour * 60 +
          state.tripSettings.exitTimeMinute;
    }).toList(growable: false);
    if (timingCandidates.isEmpty) {
      lines.add('[CHECK] Actual completion time — no suitable occurrence');
      hasCheck = true;
    } else {
      final timingTarget = timingCandidates.last;
      final plannedEnd = timingTarget.endHour * 60 + timingTarget.endMinute;

      Future<void> runTimingCase(String label, int actualMinutes) async {
        final actualNow = DateTime(
          now.year, now.month, now.day, actualMinutes ~/ 60, actualMinutes % 60,
        );
        final live = LiveController(state);
        final recalculation = ScheduleRecalculationController(state, live);
        try {
          live.startSimulation(simulatedNow: actualNow);
          live.recordExecution(TodayExecutionRecord(
            scheduleItemId: timingTarget.id,
            facilityId: timingTarget.facilityId,
            status: TodayExecutionStatus.completed,
            recordedAt: actualNow,
          ));
          final proposal = await recalculation.createProposal(
            verificationAction: 'phase-f-actual-time',
            verificationDetail: 'Debug Mode actual completion-time self-check',
          );
          if (proposal == null) {
            lines.add('[CHECK] $label — proposal could not be generated');
            hasCheck = true;
            return;
          }
          recalculation.applyProposal();
          final after = live.schedule;
          if (after == null) {
            lines.add('[FAIL] $label — applied schedule is unavailable');
            hasFail = true;
            return;
          }
          final record = live.executionRecordFor(timingTarget.id);
          final recordedAtActualTime = record?.recordedAt == actualNow;
          final notReinserted = !after.items.any(
            (item) => item.facilityId == timingTarget.facilityId,
          );
          final noOverlap = _debugOverlapCount(after.items) == 0;
          final fixedMaintained = fixedDpa.every((result) => after.items.any(
            (item) => item.facilityId == result.facilityId &&
                item.accessMethod?.name == 'dpa' &&
                item.startTimeLabel == result.time,
          ));
          final fixedDpaConflictCount = fixedDpa.fold<int>(0, (count, result) {
            final fixedItems = after.items.where(
              (item) => item.facilityId == result.facilityId &&
                  item.startTimeLabel == result.time,
            );
            var conflicts = 0;
            for (final fixed in fixedItems) {
              final fixedStart = fixed.startHour * 60 + fixed.startMinute;
              final fixedEnd = fixed.endHour * 60 + fixed.endMinute;
              conflicts += after.items.where((other) {
                if (other.id == fixed.id) return false;
                if (other.type == ScheduleItemType.entry ||
                    other.type == ScheduleItemType.exit ||
                    other.type == ScheduleItemType.breakTime) {
                  return false;
                }
                final otherStart = other.startHour * 60 + other.startMinute;
                final otherEnd = other.endHour * 60 + other.endMinute;
                return fixedStart < otherEnd && otherStart < fixedEnd;
              }).length;
            }
            return count + conflicts;
          });
          final exitMaintained = after.items.any(
            (item) => item.type == ScheduleItemType.exit &&
                item.startHour == state.tripSettings.exitTimeHour &&
                item.startMinute == state.tripSettings.exitTimeMinute,
          );
          void timingGate(String name, bool ok) {
            lines.add('[${ok ? 'PASS' : 'FAIL'}] $label — $name');
            if (!ok) hasFail = true;
          }
          timingGate('actual completion time recorded', recordedAtActualTime);
          timingGate('completed occurrence not reinserted', notReinserted);
          timingGate('fixed acquired DPA maintained', fixedMaintained);
          timingGate('acquired DPA conflicts after = 0', fixedDpaConflictCount == 0);
          timingGate('no overlaps after replan', noOverlap);
          timingGate('exit maintained', exitMaintained);
        } catch (error) {
          lines.add('[FAIL] $label — ${error.runtimeType}: $error');
          hasFail = true;
        } finally {
          recalculation.dispose();
          live.dispose();
          state.debugReplaceDayScheduleWithoutHistory(original);
        }
      }

      await runTimingCase('Early completion (-10 min)', plannedEnd - 10);
      await runTimingCase('Late completion (+10 min)', plannedEnd + 10);
    }

    // Phase F completion checks: explicit current position and live
    // conditional-wish evaluation must both reach the Today replanner.
    final selectedFacilities = state.selectedFacilitiesForPark(
      state.tripSettings.parkId,
    );
    if (selectedFacilities.isEmpty) {
      lines.add('[CHECK] Current position — no facility is available');
      hasCheck = true;
    } else {
      final location = selectedFacilities.first;
      final live = LiveController(state);
      final recalculation = ScheduleRecalculationController(state, live);
      try {
        live.startSimulation(simulatedNow: now);
        recalculation.setCurrentFacility(location.id);
        final proposal = await recalculation.createProposal(
          verificationAction: 'phase-f-current-position',
          verificationDetail: 'Debug Mode explicit current-position self-check',
        );
        final propagated = proposal?.warnings.any(
              (warning) => warning.contains('現在地: ${location.name}'),
            ) ==
            true;
        lines.add(
          '[${propagated ? 'PASS' : 'FAIL'}] Current position — explicit facility reaches replanning context',
        );
        if (!propagated) hasFail = true;
      } catch (error) {
        lines.add('[FAIL] Current position — ${error.runtimeType}: $error');
        hasFail = true;
      } finally {
        recalculation.dispose();
        live.dispose();
        state.debugReplaceDayScheduleWithoutHistory(original);
      }
    }

    final conditionalPreferences = state.effectivePlanPreferencesForToday.where(
      (preference) =>
          preference.waitTolerance.maxMinutes != null &&
          preference.priority.name != 'high' &&
          preference.priority.name != 'highest',
    ).toList(growable: false);
    if (conditionalPreferences.isEmpty) {
      lines.add('[CHECK] Conditional wish — no non-high wait-limited wish is configured');
      hasCheck = true;
    } else {
      final preference = conditionalPreferences.first;
      final matches = selectedFacilities.where(
        (value) => value.id == preference.facilityId,
      ).toList(growable: false);
      final facility = matches.isEmpty ? null : matches.first;
      if (facility == null) {
        lines.add('[CHECK] Conditional wish — configured facility is unavailable');
        hasCheck = true;
      } else {
        final live = LiveController(state);
        final recalculation = ScheduleRecalculationController(state, live);
        try {
          live.startSimulation(simulatedNow: now);
          final limit = preference.waitTolerance.maxMinutes!;
          live.setSimulationWaitTime(
            facilityId: facility.id,
            waitMinutes: limit + 10,
          );
          final proposal = await recalculation.createProposal(
            verificationAction: 'phase-f-conditional-wish',
            verificationDetail: 'Debug Mode live wait-condition self-check',
          );
          final rejected = proposal?.warnings.any(
                (warning) =>
                    warning.contains(facility.name) &&
                    warning.contains('今回は見送ります'),
              ) ==
              true;
          lines.add(
            '[${rejected ? 'PASS' : 'FAIL'}] Conditional wish — live wait above limit is respected',
          );
          if (!rejected) hasFail = true;
        } catch (error) {
          lines.add('[FAIL] Conditional wish — ${error.runtimeType}: $error');
          hasFail = true;
        } finally {
          recalculation.dispose();
          live.dispose();
          state.debugReplaceDayScheduleWithoutHistory(original);
        }
      }
    }

    final result = hasFail ? 'FAIL' : hasCheck ? 'CHECK' : 'PASS';
    lines.add('RESULT: $result');
    lines.add('===== END PHASE F EXECUTION STATUS GATE =====');
    return lines.join('\n');
  }

  int _debugOverlapCount(List<dynamic> items) {
    var count = 0;
    for (var i = 0; i < items.length; i++) {
      final a = items[i];
      final aStart = a.startHour * 60 + a.startMinute;
      final aEnd = a.endHour * 60 + a.endMinute;
      for (var j = i + 1; j < items.length; j++) {
        final b = items[j];
        final bStart = b.startHour * 60 + b.startMinute;
        final bEnd = b.endHour * 60 + b.endMinute;
        if (aStart < bEnd && bStart < aEnd) count++;
      }
    }
    return count;
  }

  bool _debugSameSchedule(dynamic a, dynamic b) {
    if (a == null || b == null || a.items.length != b.items.length) return false;
    for (var i = 0; i < a.items.length; i++) {
      final x = a.items[i];
      final y = b.items[i];
      if (x.id != y.id || x.facilityId != y.facilityId ||
          x.startHour != y.startHour || x.startMinute != y.startMinute ||
          x.endHour != y.endHour || x.endMinute != y.endMinute ||
          x.accessMethod != y.accessMethod) {
        return false;
      }
    }
    return true;
  }

  Future<void> _runAll() async {
    if (_isRunningUnifiedGate) return;
    setState(() {
      _isRunningUnifiedGate = true;
      _orchestrationReport = null;
    });
    final state = _appState!;
    final controller = _controller!;
    final todaySchedule = state.daySchedule;
    final steps = <String>[];
    try {
      // Always regenerate a PRE-TRIP reference in DEBUG. A newly-created
      // ScheduleController can see an existing TODAY schedule while lacking the
      // generation request required by the 4-mode gate.
      await controller.generateSchedule(debugNoHistory: true);
      if (controller.schedule == null || controller.errorMessage != null) {
        steps.add('[CHECK] PRE-TRIP generation — ${controller.errorMessage ?? 'no schedule'}');
      } else {
        _preTripQualitySnapshot = _qualityText(controller);
        steps.add('[PASS] PRE-TRIP reference generated independently');
        await controller.runFourModeGate();
        steps.add('[${_result(controller.fourModeGateReport)}] 4-mode PRE-TRIP reference');
      }

      // Restore the exact schedule that was present when Debug Mode was opened.
      // This does not add an Undo entry and keeps PRE-TRIP generation from
      // becoming a user-visible Today edit.
      state.debugReplaceDayScheduleWithoutHistory(todaySchedule);
      steps.add('[PASS] TODAY schedule restored after PRE-TRIP reference');

      final todayReport = await _runTodaySelfCheck();
      DebugGateRegistry.lastTodayReplanReport = todayReport;
      steps.add('[${_result(todayReport)}] TODAY replan + Undo self-check');

      final phaseFReport = await _runPhaseFExecutionStatusSelfCheck();
      DebugGateRegistry.lastPhaseFExecutionStatusReport = phaseFReport;
      steps.add('[${_result(phaseFReport)}] Phase F execution-status self-check');

      await controller.runComprehensiveGate();
      steps.add('[${_result(controller.comprehensiveGateReport)}] Comprehensive Gate');
    } catch (error) {
      state.debugReplaceDayScheduleWithoutHistory(todaySchedule);
      steps.add('[FAIL] Unified orchestration — ${error.runtimeType}: $error');
    } finally {
      _orchestrationReport = <String>[
        '===== DEBUG UNIFIED ORCHESTRATION =====',
        ...steps,
        'RESULT: ${steps.any((line) => line.startsWith('[FAIL]')) ? 'FAIL' : steps.any((line) => line.startsWith('[CHECK]')) ? 'CHECK' : 'PASS'}',
        '===== END DEBUG UNIFIED ORCHESTRATION =====',
      ].join('\n');
      if (mounted) setState(() => _isRunningUnifiedGate = false);
    }
  }

  Future<void> _runFour() async {
    final state = _appState!;
    final original = state.daySchedule;
    try {
      await _controller!.generateSchedule(debugNoHistory: true);
      _preTripQualitySnapshot = _qualityText(_controller!);
      await _controller!.runFourModeGate();
    } finally {
      state.debugReplaceDayScheduleWithoutHistory(original);
    }
  }

  Future<void> _copy() async {
    final c = _controller!;
    final state = _appState!;
    final today = DebugGateRegistry.lastTodayReplanReport;
    final acquired = state.todayAccessResults.where((r) =>
      (r.kind == TodayAccessKind.attractionDpa || r.kind == TodayAccessKind.showDpa) &&
      (r.status == TodayAccessStatus.acquired || r.status == TodayAccessStatus.won));
    final text = <String>[
      '===== Disney Planner AI ANALYSIS INFO =====',
      'Version: ${AppVersion.displayName}', 'Build number: ${AppVersion.buildNumber}',
      'Source: Debug Mode / Self-contained Unified Console',
      'Context policy: PRE-TRIP / TODAY / COMMON separated', '',
      '【PRE-TRIP PLAN QUALITY】', _preTripQualitySnapshot ?? '[CHECK] run Comprehensive Gate first',
      '', '【DPA BOUNDARY】',
      'Planned PRE-TRIP IDs: ${state.tripSettings.plannedDpaFacilityIds.isEmpty ? 'none' : state.tripSettings.plannedDpaFacilityIds.join(', ')}',
      'Acquired TODAY: ${acquired.isEmpty ? 'none' : acquired.map((r) => '${r.facilityId}${r.fixesTime ? '=${r.time}' : ''}').join(', ')}',
      '', '【UNIFIED ORCHESTRATION】', _orchestrationReport ?? '[CHECK] not executed',
      '', '【COMPREHENSIVE GATE】', c.comprehensiveGateReport ?? '[CHECK] not executed',
      '', '【TODAY REPLAN VERIFICATION】', today ?? '[CHECK] not executed',
      '', '【PHASE F EXECUTION STATUS】', DebugGateRegistry.lastPhaseFExecutionStatusReport ?? '[CHECK] not executed',
      '', '【4-MODE PRE-TRIP REFERENCE】', c.fourModeGateReport ?? '[CHECK] not executed',
      '===== END AI ANALYSIS INFO =====',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI解析情報をコピーしました。')));
  }

  @override Widget build(BuildContext context) {
    assert(kDebugMode);
    final c = _controller;
    if (c == null) return const Center(child: CircularProgressIndicator());
    final comp = c.comprehensiveGateReport;
    final four = c.fourModeGateReport;
    final today = DebugGateRegistry.lastTodayReplanReport;
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.bug_report_outlined), const SizedBox(width: 10), Expanded(child: Text('統合デバッグコンソール', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)))]),
        const SizedBox(height: 6), const Text('DEBUG専用画面です。総合GateがPRE-TRIP生成・4モード・TODAY再計画＋Undoを自己完結で検証します。'),
        const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: [Chip(label: Text('総合 ${_result(comp)}')), Chip(label: Text('Today ${_result(today)}')), Chip(label: Text('4モード ${_result(four)}'))]),
        if (_preTripQualitySnapshot != null) ...[const SizedBox(height: 8), Text('PRE-TRIP参照：${_preTripQualitySnapshot!.replaceAll('\n', ' / ')}')],
        const SizedBox(height: 14), Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(onPressed: _isRunningUnifiedGate ? null : _runAll, icon: const Icon(Icons.fact_check_outlined), label: Text(_isRunningUnifiedGate ? '総合確認中…' : '総合Gateを実行')),
          OutlinedButton.icon(onPressed: _copy, icon: const Icon(Icons.copy_all_outlined), label: const Text('AI解析情報をコピー')),
          TextButton.icon(onPressed: c.isRunningFourModeGate || _isRunningUnifiedGate ? null : _runFour, icon: const Icon(Icons.tune), label: const Text('4モード個別実行')),
        ]),
      ])), const SizedBox(height: 12),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(onTap: () => setState(() => _expanded = !_expanded), child: Row(children: [Expanded(child: Text('解析詳細', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))), Icon(_expanded ? Icons.expand_less : Icons.expand_more)])),
        if (_expanded) ...[
          const SizedBox(height: 12), _Report('Unified orchestration', _orchestrationReport ?? '[CHECK] 未実行'),
          const SizedBox(height: 16), _Report('Comprehensive Gate', comp ?? '[CHECK] 未実行'),
          const SizedBox(height: 16), _Report('Today Replan Verification', today ?? '[CHECK] 未実行'),
          const SizedBox(height: 16), _Report('Phase F Execution Status', DebugGateRegistry.lastPhaseFExecutionStatusReport ?? '[CHECK] 未実行'),
          const SizedBox(height: 16), _Report('4-mode PRE-TRIP reference', four ?? '[CHECK] 未実行'),
        ],
      ])),
    ]));
  }
}

class _Report extends StatelessWidget {
  const _Report(this.title, this.report); final String title; final String report;
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 5), SelectableText(report, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'))]);
}
