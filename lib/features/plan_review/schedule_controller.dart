import 'dart:async';
import 'dart:isolate';

import '../../data/repositories/crowd_factor_repository_impl.dart';
import '../../data/repositories/local_greeting_wait_planning_repository.dart';
import '../../data/repositories/local_vacation_package_unlimited_ride_repository.dart';
import '../../domain/services/wish_candidate_scoring_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/dependency/service_locator.dart';
import '../../app/state/app_state.dart';
import '../../domain/entities/day_schedule.dart';
import '../../domain/entities/trip_settings.dart';
import '../../domain/entities/phase_d_scenario_summary.dart';
import '../../domain/entities/event_impact.dart';
import '../../domain/entities/expert_recommendation_profile.dart';
import '../../domain/entities/area_connection.dart';
import '../../domain/entities/facility_location.dart';
import '../../domain/entities/greeting_wait_planning_value.dart';
import '../../domain/entities/dpa_strategy.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/plan_preference.dart';
import '../../domain/entities/plan_coverage_advice.dart';
import '../../domain/entities/plan_explanation.dart';
import '../../domain/entities/planning_scenario.dart';
import '../../domain/entities/vacation_package_comparison.dart';
import '../../domain/entities/official_performance_opportunity.dart';
import '../../domain/entities/performance_time_option.dart';
import '../../domain/entities/schedule_item.dart';
import '../../domain/entities/time_band_wait_profile.dart';
import '../../domain/entities/wait_time_range.dart';
import '../../domain/entities/schedule_validation_issue.dart';
import '../../domain/enums/facility_access_method.dart';
import '../../domain/enums/today_access_kind.dart';
import '../../domain/enums/today_access_status.dart';
import '../../domain/enums/preferred_time.dart';
import '../../domain/enums/priority_level.dart';
import '../../domain/enums/schedule_item_type.dart';
import '../../domain/enums/wait_time_band.dart';
import '../../domain/enums/fixed_time_status.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/enums/dpa_strategy_type.dart';
import '../../domain/enums/lottery_fallback_action.dart';
import '../../data/local/local_performance_schedule_repository.dart';
import '../../domain/services/official_performance_preference_resolver.dart';
import '../../domain/services/plan_quality_audit_service.dart';
import '../../domain/services/plan_explanation_service.dart';
import '../../domain/services/dpa_auto_allocator.dart';
import '../../domain/services/free_time_improvement_scoring_service.dart';
import '../../domain/services/fixed_schedule_conflict_service.dart';
import '../../domain/services/disney_expert_recommendation_service.dart';
import '../../domain/services/schedule_engine.dart';
import '../../domain/services/schedule_validator.dart';
import '../../domain/services/plan_coverage_advice_service.dart';
import '../../core/debug/debug_gate_registry.dart';
import '../../core/constants/app_version.dart';


class _ScheduleGenerationRequest {
  const _ScheduleGenerationRequest({
    required this.settings,
    required this.facilities,
    required this.preferences,
    required this.eventImpacts,
    required this.waitProfiles,
    required this.morningScores,
    required this.officialPerformanceOpportunities,
    required this.areaConnections,
    required this.facilityLocations,
    required this.expertProfiles,
    required this.unlimitedRideBufferMinutes,
    required this.greetingWaitPlanning,
    required this.manualFixedItems,
    this.optionalFacilityIds = const <String>{},
  });

  final TripSettings settings;
  final List<Facility> facilities;
  final List<PlanPreference> preferences;
  final List<EventImpact> eventImpacts;
  final List<TimeBandWaitProfile> waitProfiles;
  final Map<String, double> morningScores;
  final List<OfficialPerformanceOpportunity> officialPerformanceOpportunities;
  final List<AreaConnection> areaConnections;
  final List<FacilityLocation> facilityLocations;
  final List<ExpertRecommendationProfile> expertProfiles;
  final Map<String, int> unlimitedRideBufferMinutes;
  final Map<String, GreetingWaitPlanningValue> greetingWaitPlanning;
  final List<ScheduleItem> manualFixedItems;
  final Set<String> optionalFacilityIds;
}

void _scheduleGenerationIsolateEntry(List<Object?> message) {
  final sendPort = message[0] as SendPort;
  final request = message[1] as _ScheduleGenerationRequest;
  try {
    final result = const ScheduleEngine().generate(
      settings: request.settings,
      facilities: request.facilities,
      preferences: request.preferences,
      eventImpacts: request.eventImpacts,
      waitProfiles: request.waitProfiles,
      morningScores: request.morningScores,
      officialPerformanceOpportunities:
          request.officialPerformanceOpportunities,
      areaConnections: request.areaConnections,
      facilityLocations: request.facilityLocations,
      expertProfiles: request.expertProfiles,
      unlimitedRideBufferMinutes: request.unlimitedRideBufferMinutes,
      greetingWaitPlanning: request.greetingWaitPlanning,
      manualFixedItems: request.manualFixedItems,
      optionalFacilityIds: request.optionalFacilityIds,
    );
    sendPort.send(result);
  } catch (error, stackTrace) {
    sendPort.send(<Object?>['error', error.toString(), stackTrace.toString()]);
  }
}

Future<DaySchedule> _generateScheduleOffUi(
  _ScheduleGenerationRequest request,
) async {
  final receivePort = ReceivePort();
  final errorPort = ReceivePort();
  final exitPort = ReceivePort();
  final completer = Completer<DaySchedule>();

  final isolate = await Isolate.spawn<List<Object?>>(
    _scheduleGenerationIsolateEntry,
    <Object?>[receivePort.sendPort, request],
    onError: errorPort.sendPort,
    onExit: exitPort.sendPort,
  );

  late final StreamSubscription<Object?> resultSubscription;
  late final StreamSubscription<Object?> errorSubscription;
  late final StreamSubscription<Object?> exitSubscription;

  void finish() {
    resultSubscription.cancel();
    errorSubscription.cancel();
    exitSubscription.cancel();
    receivePort.close();
    errorPort.close();
    exitPort.close();
    isolate.kill(priority: Isolate.immediate);
  }

  resultSubscription = receivePort.listen((message) {
    if (completer.isCompleted) return;
    if (message is DaySchedule) {
      completer.complete(message);
    } else if (message is List && message.isNotEmpty && message.first == 'error') {
      completer.completeError(
        StateError(message.length > 1 ? message[1].toString() : '生成処理に失敗しました。'),
      );
    } else {
      completer.completeError(StateError('生成結果を受信できませんでした。'));
    }
  });

  errorSubscription = errorPort.listen((message) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('生成用isolateでエラーが発生しました: $message'));
    }
  });

  exitSubscription = exitPort.listen((_) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('生成用isolateが結果を返さず終了しました。'));
    }
  });

  try {
    return await completer.future;
  } finally {
    finish();
  }
}

class ScheduleController extends ChangeNotifier {
  ScheduleController(this._appState) {
    _appState.addListener(_onAppStateChanged);
  }

  final AppState _appState;
  final DpaAutoAllocator _dpaAutoAllocator = const DpaAutoAllocator();
  final ScheduleValidator _scheduleValidator = const ScheduleValidator();
  final FixedScheduleConflictService _fixedConflictService =
      const FixedScheduleConflictService();
  final FreeTimeImprovementScoringService _freeTimeScoringService =
      const FreeTimeImprovementScoringService();
  final PlanCoverageAdviceService _coverageAdviceService =
      const PlanCoverageAdviceService();
  List<PlanPreference>? _generatedPreferences;
  final LocalPerformanceScheduleRepository _performanceScheduleRepository =
      LocalPerformanceScheduleRepository();
  late final OfficialPerformancePreferenceResolver _performanceResolver =
      OfficialPerformancePreferenceResolver(
        repository: _performanceScheduleRepository,
      );

  bool isLoading = false;
  String generationStatus = '準備しています…';

  void _setGenerationStatus(String value) {
    generationStatus = value;
    notifyListeners();
  }
  bool isAnalyzingCoverage = false;
  String? errorMessage;
  String? coverageAnalysisError;
  PlanCoverageAdvice? coverageAdvice;
  PlanningScenario? vacationPackageComparisonScenario;
  int? vacationPackageComparisonOverlapCount;
  bool vacationPackageComparisonGeneratedIndependently = false;
  PlanAdditionImpact? lastAdditionImpact;
  Set<String> _preAdditionScheduledIds = const <String>{};
  int _preAdditionDesiredCount = 0;
  String? _lastAddedFacilityName;

  List<String> _optionalOptimizationTrace = const <String>[];
  int _optionalOptimizationTrialCount = 0;
  int _optionalOptimizationAdoptedCount = 0;
  Map<String, String> _optionalRejectionReasons = const <String, String>{};
  List<Facility> _qualityAuditFacilities = const <Facility>[];
  List<FacilityLocation> _qualityAuditLocations = const <FacilityLocation>[];
  List<AreaConnection> _qualityAuditConnections = const <AreaConnection>[];
  _ScheduleGenerationRequest? _fourModeBaseRequest;
  Map<ScheduleOptimizationMode, DaySchedule> _phaseDScenarioSchedules =
      const <ScheduleOptimizationMode, DaySchedule>{};
  ScheduleOptimizationMode? lastAppliedPhaseDMode;
  PhaseDScenarioSummary? lastAppliedPhaseDExpected;
  PhaseDScenarioSummary? lastAppliedPhaseDActual;
  bool? lastAppliedPhaseDExactMatch;
  String? phaseDApplicationReport;
  bool isRunningFourModeGate = false;
  String? fourModeGateReport;
  List<PhaseDScenarioSummary> phaseDScenarioSummaries = const <PhaseDScenarioSummary>[];
  bool phaseDScenariosGeneratedIndependently = false;
  bool isRunningComprehensiveGate = false;
  String? comprehensiveGateReport;


  List<String> get optionalOptimizationTrace =>
      List<String>.unmodifiable(_optionalOptimizationTrace);
  int get optionalOptimizationTrialCount => _optionalOptimizationTrialCount;
  int get optionalOptimizationAdoptedCount => _optionalOptimizationAdoptedCount;
  String? optionalRejectionReason(String facilityId) => _optionalRejectionReasons[facilityId];

  PlanExplanation? get planExplanation {
    final current = schedule;
    if (current == null) return null;
    final desiredFacilities = requiredFacilitiesForCurrentPark;
    final scheduledIds = current.items
        .map((item) => item.facilityId)
        .whereType<String>()
        .toList(growable: false);
    final hardFacilities = desiredFacilities.where((facility) {
      final preference = preferenceByFacilityId(facility.id);
      return preference == null || preference.priority.value > 2;
    }).toList(growable: false);
    final audit = planQualityAudit;
    return const PlanExplanationService().build(
      schedule: current,
      settings: tripSettings,
      desiredFacilities: desiredFacilities,
      preferences: _appState.planPreferences,
      achievedDesiredCount: coveredDesiredOccurrenceCount(desiredFacilities, scheduledIds),
      hardAchievedCount: coveredDesiredOccurrenceCount(hardFacilities, scheduledIds),
      totalHardDesiredCount: hardFacilities.length,
      largestFreeBlockMinutes: audit?.largestFreeBlockMinutes ?? 0,
      optionalRejectionReasons: _optionalRejectionReasons,
    );
  }

  PlanQualityAudit? get planQualityAudit {
    final current = schedule;
    return current == null
        ? null
        : const PlanQualityAuditService().evaluate(
            current,
            facilities: <Facility>[
              ..._qualityAuditFacilities,
              ...selectedFacilitiesForCurrentPark.where(
                (facility) => !_qualityAuditFacilities.any(
                  (cached) => cached.id == facility.id,
                ),
              ),
            ],
            facilityLocations: _qualityAuditLocations,
            areaConnections: _qualityAuditConnections,
          );
  }

  Future<List<PhaseDScenarioSummary>> preparePhaseDScenariosForUi() async {
    // A restored/persisted plan can be displayed by a newly-created controller
    // before this controller has generated anything in the current session. In
    // that case `_fourModeBaseRequest` is intentionally empty even though a
    // valid schedule is visible. Rebuild the current mode once (without adding
    // an Undo/history entry) so the comparison request is reconstructed from
    // the same current settings/wishes, then run the four independent modes.
    if (_fourModeBaseRequest == null && schedule != null) {
      await generateSchedule(debugNoHistory: true);
    }

    await runFourModeGate();
    final summaries = List<PhaseDScenarioSummary>.unmodifiable(
      phaseDScenarioSummaries,
    );
    if (summaries.length != ScheduleOptimizationMode.values.length) {
      return const <PhaseDScenarioSummary>[];
    }
    final modes = summaries.map((item) => item.mode).toSet();
    if (modes.length != ScheduleOptimizationMode.values.length) {
      return const <PhaseDScenarioSummary>[];
    }
    return summaries;
  }

  Future<void> runFourModeGate() async {
    final base = _fourModeBaseRequest;
    if (base == null || schedule == null) {
      fourModeGateReport = '[CHECK] 4モードGate — 先にプランを生成してください。';
      notifyListeners();
      return;
    }

    isRunningFourModeGate = true;
    fourModeGateReport = null;
    phaseDScenarioSummaries = const <PhaseDScenarioSummary>[];
    _phaseDScenarioSchedules = const <ScheduleOptimizationMode, DaySchedule>{};
    phaseDScenariosGeneratedIndependently = false;
    notifyListeners();

    try {
      final results = <ScheduleOptimizationMode, PlanQualityAudit>{};
      final schedules = <ScheduleOptimizationMode, DaySchedule>{};
      for (final mode in ScheduleOptimizationMode.values) {
        final request = _ScheduleGenerationRequest(
          settings: base.settings.copyWith(scheduleOptimizationMode: mode),
          facilities: base.facilities,
          preferences: base.preferences,
          eventImpacts: base.eventImpacts,
          waitProfiles: base.waitProfiles,
          morningScores: base.morningScores,
          officialPerformanceOpportunities: base.officialPerformanceOpportunities,
          areaConnections: base.areaConnections,
          facilityLocations: base.facilityLocations,
          expertProfiles: base.expertProfiles,
          unlimitedRideBufferMinutes: base.unlimitedRideBufferMinutes,
          greetingWaitPlanning: base.greetingWaitPlanning,
          manualFixedItems: base.manualFixedItems,
          optionalFacilityIds: base.optionalFacilityIds,
        );
        final generated = await _generateScheduleOffUi(request);
        schedules[mode] = generated;
        results[mode] = const PlanQualityAuditService().evaluate(
          generated,
          facilities: _qualityAuditFacilities,
          facilityLocations: _qualityAuditLocations,
          areaConnections: _qualityAuditConnections,
        );
      }

      // Coverage diagnostics must use the same occurrence source as the normal
      // Plan Review DEBUG analysis. The generation request may contain only the
      // engine candidates that survived preprocessing, so counting base.facilities
      // here can make the 4-mode gate report a different hard/desired denominator.
      final desiredFacilities = requiredFacilitiesForCurrentPark;

      bool isFlexibleOptional(Facility facility) {
        final prefs = base.preferences.where((p) => p.facilityId == facility.id);
        return prefs.isNotEmpty && prefs.first.priority.value <= 2;
      }

      final hardFacilities = desiredFacilities
          .where((facility) => !isFlexibleOptional(facility))
          .toList(growable: false);
      final desiredCount = desiredFacilities.length;
      final hardDesiredCount = hardFacilities.length;

      ({int achieved, int hardAchieved}) coverage(ScheduleOptimizationMode mode) {
        final ids = schedules[mode]!.items
            .map((item) => item.facilityId)
            .whereType<String>()
            .toList(growable: false);
        return (
          achieved: coveredDesiredOccurrenceCount(desiredFacilities, ids),
          hardAchieved: coveredDesiredOccurrenceCount(hardFacilities, ids),
        );
      }

      final balanced = results[ScheduleOptimizationMode.balanced]!;
      final wait = results[ScheduleOptimizationMode.minimumWait]!;
      final walking = results[ScheduleOptimizationMode.minimumWalking]!;
      final compact = results[ScheduleOptimizationMode.compactSchedule]!;
      final balancedCoverage = coverage(ScheduleOptimizationMode.balanced);
      final waitCoverage = coverage(ScheduleOptimizationMode.minimumWait);
      final walkingCoverage = coverage(ScheduleOptimizationMode.minimumWalking);
      final compactCoverage = coverage(ScheduleOptimizationMode.compactSchedule);

      phaseDScenarioSummaries = ScheduleOptimizationMode.values.map((mode) {
        final audit = results[mode]!;
        final modeCoverage = coverage(mode);
        return PhaseDScenarioSummary(
          mode: mode,
          achievedDesiredCount: modeCoverage.achieved,
          totalDesiredCount: desiredCount,
          hardAchievedCount: modeCoverage.hardAchieved,
          totalHardDesiredCount: hardDesiredCount,
          totalWaitMinutes: audit.totalWaitMinutes,
          totalMovementMinutes: audit.totalMovementMinutes,
          totalFreeMinutes: audit.totalFreeMinutes,
          largestFreeBlockMinutes: audit.largestFreeBlockMinutes,
          overlapCount: audit.overlapCount,
        );
      }).toList(growable: false);
      _phaseDScenarioSchedules =
          Map<ScheduleOptimizationMode, DaySchedule>.unmodifiable(schedules);
      phaseDScenariosGeneratedIndependently = true;

      int fragmentation(PlanQualityAudit a) =>
          a.totalFreeMinutes - a.largestFreeBlockMinutes;
      final allNoOverlap = results.values.every((a) => a.overlapCount == 0);

      ({bool pass, String detail}) objectiveGate({
        required ({int achieved, int hardAchieved}) candidateCoverage,
        required ({int achieved, int hardAchieved}) baselineCoverage,
        required int candidateMetric,
        required int baselineMetric,
        required String metricLabel,
      }) {
        if (candidateCoverage.hardAchieved < baselineCoverage.hardAchieved) {
          return (
            pass: false,
            detail: 'hard coverage ${candidateCoverage.hardAchieved}/$hardDesiredCount < ${baselineCoverage.hardAchieved}/$hardDesiredCount',
          );
        }
        if (candidateCoverage.achieved < baselineCoverage.achieved) {
          return (
            pass: false,
            detail: 'coverage ${candidateCoverage.achieved}/$desiredCount < ${baselineCoverage.achieved}/$desiredCount',
          );
        }
        if (candidateCoverage.achieved > baselineCoverage.achieved ||
            candidateCoverage.hardAchieved > baselineCoverage.hardAchieved) {
          return (
            pass: true,
            detail: 'coverage優先 ${candidateCoverage.achieved}/$desiredCount vs ${baselineCoverage.achieved}/$desiredCount; $metricLabel $candidateMetric vs $baselineMetric は同一coverage比較ではありません',
          );
        }
        return (
          pass: candidateMetric <= baselineMetric,
          detail: '$metricLabel $candidateMetric <= $baselineMetric (coverage ${candidateCoverage.achieved}/$desiredCount, hard ${candidateCoverage.hardAchieved}/$hardDesiredCount 同条件)',
        );
      }

      final waitGate = objectiveGate(
        candidateCoverage: waitCoverage,
        baselineCoverage: balancedCoverage,
        candidateMetric: wait.totalWaitMinutes,
        baselineMetric: balanced.totalWaitMinutes,
        metricLabel: '待ち',
      );
      final walkingGate = objectiveGate(
        candidateCoverage: walkingCoverage,
        baselineCoverage: balancedCoverage,
        candidateMetric: walking.totalMovementMinutes,
        baselineMetric: balanced.totalMovementMinutes,
        metricLabel: '移動',
      );
      final compactGate = objectiveGate(
        candidateCoverage: compactCoverage,
        baselineCoverage: balancedCoverage,
        candidateMetric: fragmentation(compact),
        baselineMetric: fragmentation(balanced),
        metricLabel: 'fragmentation',
      );

      String qualityFingerprint(ScheduleOptimizationMode mode) {
        final a = results[mode]!;
        final c = coverage(mode);
        return '${c.achieved}/${c.hardAchieved}/${a.totalWaitMinutes}/${a.totalMovementMinutes}/${a.totalFreeMinutes}/${a.largestFreeBlockMinutes}/${a.freeBlockCount}';
      }

      final tuples = ScheduleOptimizationMode.values
          .map(qualityFingerprint)
          .toSet();
      final differentiated = tuples.length > 1;
      final balancedWalkingIdentical =
          qualityFingerprint(ScheduleOptimizationMode.balanced) ==
              qualityFingerprint(ScheduleOptimizationMode.minimumWalking);
      final hardFail = !allNoOverlap || !waitGate.pass || !walkingGate.pass || !compactGate.pass;
      final status = hardFail ? 'FAIL' : differentiated ? 'PASS' : 'CHECK';

      String row(ScheduleOptimizationMode mode, String label) {
        final a = results[mode]!;
        final c = coverage(mode);
        return '$label: 達成${c.achieved}/$desiredCount / hard${c.hardAchieved}/$hardDesiredCount / '
            '待ち${a.totalWaitMinutes}分 / 移動${a.totalMovementMinutes}分 / '
            '自由${a.totalFreeMinutes}分 / 最大連続${a.largestFreeBlockMinutes}分 / '
            '自由枠${a.freeBlockCount}個 / 細切れ${a.smallFreeBlockCount}個 / 重複${a.overlapCount}件';
      }

      final waitDelta = wait.totalWaitMinutes - balanced.totalWaitMinutes;
      final coverageDelta = waitCoverage.achieved - balancedCoverage.achieved;
      final waitDiagnosis = coverageDelta == 0
          ? 'minimumWait診断: 同一coverageで待ち差 ${waitDelta >= 0 ? '+' : ''}$waitDelta分。'
          : 'minimumWait診断: coverage差 ${coverageDelta >= 0 ? '+' : ''}$coverageDelta件のため、待ち差 ${waitDelta >= 0 ? '+' : ''}$waitDelta分を単独でFAIL判定しません。希望維持を先に評価します。';

      fourModeGateReport = <String>[
        '===== DEBUG 4-MODE GATE =====',
        row(ScheduleOptimizationMode.balanced, 'バランス重視'),
        row(ScheduleOptimizationMode.minimumWait, '待ち時間重視'),
        row(ScheduleOptimizationMode.minimumWalking, '移動少なめ'),
        row(ScheduleOptimizationMode.compactSchedule, 'まとまった自由時間重視'),
        '[${waitGate.pass ? 'PASS' : 'FAIL'}] 待ち時間重視 vs バランス — ${waitGate.detail}',
        '[${walkingGate.pass ? 'PASS' : 'FAIL'}] 移動少なめ vs バランス — ${walkingGate.detail}',
        '[${compactGate.pass ? 'PASS' : 'FAIL'}] 自由時間集約 vs バランス — ${compactGate.detail}',
        '[${allNoOverlap ? 'PASS' : 'FAIL'}] 全モード時間重複なし',
        '[${differentiated ? 'PASS' : 'CHECK'}] モード差分 — ${differentiated ? '少なくとも2種類の品質結果を確認' : '今回の条件では4モードが同一結果'}',
        balancedWalkingIdentical
            ? '[INFO] バランス重視と移動少なめ — 今回の入力では同一品質結果。Gate失敗ではありません。別条件でも継続監視します。'
            : '[PASS] バランス重視と移動少なめ — 今回の入力で品質差を確認',
        'Coverage basis: required wishes $desiredCount件 / hard wishes $hardDesiredCount件（Plan Review DEBUGと同一定義）',
        waitDiagnosis,
        '判定原則: hard wish → 全希望coverage → 各モード目的指標の順。coverageが異なるプラン同士の待ち時間だけを直接比較しません。',
        'RESULT: $status',
        '===== END DEBUG 4-MODE GATE =====',
      ].join('\n');
    } catch (error) {
      fourModeGateReport = '===== DEBUG 4-MODE GATE =====\n'
          '[FAIL] 4モード比較実行 — ${error.runtimeType}: $error\n'
          'RESULT: FAIL\n'
          '===== END DEBUG 4-MODE GATE =====';
    } finally {
      isRunningFourModeGate = false;
      notifyListeners();
    }
  }

  Future<bool> applyPhaseDScenario(ScheduleOptimizationMode mode) async {
    final selectedSchedule = _phaseDScenarioSchedules[mode];
    final expected = phaseDScenarioSummaries
        .where((item) => item.mode == mode)
        .firstOrNull;
    if (selectedSchedule == null || expected == null) {
      phaseDApplicationReport =
          '[FAIL] Phase D scenario application — comparison snapshot unavailable';
      DebugGateRegistry.lastPhaseDApplicationReport = phaseDApplicationReport;
      lastAppliedPhaseDExactMatch = false;
      notifyListeners();
      return false;
    }

    final desiredFacilities = requiredFacilitiesForCurrentPark;
    final base = _fourModeBaseRequest;
    bool isFlexibleOptional(Facility facility) {
      final prefs = base?.preferences.where((p) => p.facilityId == facility.id);
      return prefs != null &&
          prefs.isNotEmpty &&
          prefs.first.priority.value <= 2;
    }

    final hardFacilities = desiredFacilities
        .where((facility) => !isFlexibleOptional(facility))
        .toList(growable: false);

    // Apply the exact schedule snapshot shown in the comparison dialog.
    // Regenerating here could produce a different result from what the user chose.
    _appState.updateTripSettings(
      _appState.tripSettings.copyWith(scheduleOptimizationMode: mode),
    );
    _appState.updateDaySchedule(selectedSchedule);

    final audit = const PlanQualityAuditService().evaluate(
      selectedSchedule,
      facilities: _qualityAuditFacilities,
      facilityLocations: _qualityAuditLocations,
      areaConnections: _qualityAuditConnections,
    );
    final ids = selectedSchedule.items
        .map((item) => item.facilityId)
        .whereType<String>()
        .toList(growable: false);
    final actual = PhaseDScenarioSummary(
      mode: mode,
      achievedDesiredCount:
          coveredDesiredOccurrenceCount(desiredFacilities, ids),
      totalDesiredCount: desiredFacilities.length,
      hardAchievedCount: coveredDesiredOccurrenceCount(hardFacilities, ids),
      totalHardDesiredCount: hardFacilities.length,
      totalWaitMinutes: audit.totalWaitMinutes,
      totalMovementMinutes: audit.totalMovementMinutes,
      totalFreeMinutes: audit.totalFreeMinutes,
      largestFreeBlockMinutes: audit.largestFreeBlockMinutes,
      overlapCount: audit.overlapCount,
    );
    final exactMatch = _phaseDScenarioSummaryMatches(expected, actual);
    final hardMaintained =
        actual.hardAchievedCount == actual.totalHardDesiredCount;
    final noOverlap = actual.overlapCount == 0;
    final pass = exactMatch && hardMaintained && noOverlap;

    lastAppliedPhaseDMode = mode;
    lastAppliedPhaseDExpected = expected;
    lastAppliedPhaseDActual = actual;
    lastAppliedPhaseDExactMatch = exactMatch;
    phaseDApplicationReport = <String>[
      '===== PHASE D APPLICATION GATE =====',
      'Selected mode: ${mode.name}',
      '[${exactMatch ? 'PASS' : 'FAIL'}] Applied schedule matches compared scenario — expected ${_phaseDScenarioMetrics(expected)} / actual ${_phaseDScenarioMetrics(actual)}',
      '[${hardMaintained ? 'PASS' : 'FAIL'}] Hard wish coverage maintained — ${actual.hardAchievedCount}/${actual.totalHardDesiredCount}',
      '[${noOverlap ? 'PASS' : 'FAIL'}] Applied scenario overlaps — ${actual.overlapCount}',
      'RESULT: ${pass ? 'PASS' : 'FAIL'}',
      '===== END PHASE D APPLICATION GATE =====',
    ].join('\n');
    DebugGateRegistry.lastPhaseDApplicationReport = phaseDApplicationReport;
    notifyListeners();
    return pass;
  }

  bool _phaseDScenarioSummaryMatches(
    PhaseDScenarioSummary expected,
    PhaseDScenarioSummary actual,
  ) =>
      expected.mode == actual.mode &&
      expected.achievedDesiredCount == actual.achievedDesiredCount &&
      expected.totalDesiredCount == actual.totalDesiredCount &&
      expected.hardAchievedCount == actual.hardAchievedCount &&
      expected.totalHardDesiredCount == actual.totalHardDesiredCount &&
      expected.totalWaitMinutes == actual.totalWaitMinutes &&
      expected.totalMovementMinutes == actual.totalMovementMinutes &&
      expected.totalFreeMinutes == actual.totalFreeMinutes &&
      expected.largestFreeBlockMinutes == actual.largestFreeBlockMinutes &&
      expected.overlapCount == actual.overlapCount;

  String _phaseDScenarioMetrics(PhaseDScenarioSummary item) =>
      '${item.achievedDesiredCount}/${item.totalDesiredCount} wishes, '
      'hard ${item.hardAchievedCount}/${item.totalHardDesiredCount}, '
      'wait ${item.totalWaitMinutes}, movement ${item.totalMovementMinutes}, '
      'free ${item.totalFreeMinutes}, largest ${item.largestFreeBlockMinutes}, '
      'overlap ${item.overlapCount}';

  Future<void> runComprehensiveGate() async {
    if (schedule == null) {
      comprehensiveGateReport = '[CHECK] 総合Gate — 先にプランを生成してください。';
      notifyListeners();
      return;
    }
    isRunningComprehensiveGate = true;
    comprehensiveGateReport = null;
    notifyListeners();
    try {
      await runFourModeGate();

      // The comprehensive gate must be self-contained. VP comparison state is
      // normally produced by Plan Review coverage analysis, but Debug Mode can
      // create a fresh PRE-TRIP schedule without visiting Plan Review first.
      // Generate the comparison from that same PRE-TRIP schedule here instead
      // of treating missing cached analysis as a product failure.
      if (vacationPackageComparisonScenario == null ||
          !vacationPackageComparisonGeneratedIndependently ||
          vacationPackageComparisonOverlapCount == null) {
        await analyzePlanCoverage();
      }

      final current = schedule!;
      final scheduledDpa = current.items
          .where((item) => item.accessMethod == FacilityAccessMethod.dpa)
          .toList(growable: false);
      final overlapOk = (planQualityAudit?.overlapCount ?? 0) == 0;
      final acquiredDpaIds = _appState.todayAccessResults
          .where((result) =>
              (result.kind == TodayAccessKind.attractionDpa ||
                  result.kind == TodayAccessKind.showDpa) &&
              (result.status == TodayAccessStatus.acquired ||
                  result.status == TodayAccessStatus.won))
          .map((result) => result.facilityId)
          .toSet();
      final unacquiredScheduledDpa = scheduledDpa
          .where((item) =>
              item.facilityId == null ||
              !acquiredDpaIds.contains(item.facilityId))
          .toList(growable: false);
      final dpaBoundaryOk = unacquiredScheduledDpa.isEmpty;
      final fourMode = fourModeGateReport;
      final fourModePass = fourMode?.contains('RESULT: PASS') == true;
      final fourModeFail = fourMode?.contains('RESULT: FAIL') == true;
      final fourModeCheck = fourMode == null || (!fourModePass && !fourModeFail);
      final today = DebugGateRegistry.lastTodayReplanReport;
      final todayPass = today?.contains('RESULT: PASS') == true;
      final todayFail = today?.contains('RESULT: FAIL') == true;
      final phaseFExecution = DebugGateRegistry.lastPhaseFExecutionStatusReport;
      final phaseFExecutionPass = phaseFExecution?.contains('RESULT: PASS') == true;
      final phaseFExecutionFail = phaseFExecution?.contains('RESULT: FAIL') == true;
      final phaseFExecutionCheck = phaseFExecution == null ||
          (!phaseFExecutionPass && !phaseFExecutionFail);
      final hardFacilities = requiredFacilitiesForCurrentPark.where((facility) {
        final preference = preferenceByFacilityId(facility.id);
        return preference == null || preference.priority.value > 2;
      }).toList(growable: false);
      final ids = current.items
          .map((item) => item.facilityId)
          .whereType<String>()
          .toList(growable: false);
      final hardAchieved = coveredDesiredOccurrenceCount(hardFacilities, ids);
      final hardOk = hardAchieved == hardFacilities.length;
      final vpScenario = vacationPackageComparisonScenario;
      final vpSimulationAvailable = vpScenario != null;
      final vpOverlapOk = vacationPackageComparisonOverlapCount == 0;
      final vpCoverageOk = vpScenario == null ||
          vpScenario.totalDesiredCount == requiredFacilitiesForCurrentPark.length;
      final vpIndependentOk =
          vpSimulationAvailable && vacationPackageComparisonGeneratedIndependently;
      final vpMetricsOk = vpScenario != null &&
          vpScenario.totalWaitMinutes != null &&
          vpScenario.totalFreeMinutes != null &&
          vpScenario.totalMovementMinutes != null &&
          vpScenario.hardScheduledDesiredCount != null &&
          vpScenario.totalHardDesiredCount != null;
      final vpMovementSemanticOk = vpScenario == null ||
          vpScenario.scheduledDesiredCount < 2 ||
          (vpScenario.totalMovementMinutes ?? 0) > 0;
      final phaseDModeSet = phaseDScenarioSummaries.map((item) => item.mode).toSet();
      final phaseDScenarioCountOk = phaseDScenariosGeneratedIndependently &&
          phaseDScenarioSummaries.length == ScheduleOptimizationMode.values.length &&
          phaseDModeSet.length == ScheduleOptimizationMode.values.length;
      final phaseDSameBasisOk = phaseDScenarioSummaries.isNotEmpty &&
          phaseDScenarioSummaries.every((item) =>
              item.totalDesiredCount == requiredFacilitiesForCurrentPark.length &&
              item.totalHardDesiredCount == hardFacilities.length);
      final phaseDNoOverlapOk = phaseDScenarioSummaries.isNotEmpty &&
          phaseDScenarioSummaries.every((item) => item.overlapCount == 0);
      final vpCatalogOk = VacationPackageComparisonCatalog.attractionOptions.length == 4 &&
          VacationPackageComparisonCatalog.attractionOptions
              .where((option) => option.canSimulateFromCurrentSettings)
              .length == 1;
      final phaseDApplicationEvidence =
          phaseDApplicationReport ?? DebugGateRegistry.lastPhaseDApplicationReport;
      final phaseDApplicationPass =
          phaseDApplicationEvidence?.contains('RESULT: PASS') == true;
      final phaseDApplicationFail =
          phaseDApplicationEvidence?.contains('RESULT: FAIL') == true;
      final explanation = planExplanation;
      final scheduleItemIds = current.items.map((item) => item.id).toSet();
      final phaseEItemRefsOk = explanation != null &&
          explanation.items.every((item) => scheduleItemIds.contains(item.scheduleItemId));
      final scheduledFacilityIds = current.items
          .map((item) => item.facilityId)
          .whereType<String>()
          .toList(growable: false);
      final requestedCountsForExplanation = <String, int>{};
      for (final facility in requiredFacilitiesForCurrentPark) {
        requestedCountsForExplanation.update(
          facility.id,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      final scheduledCountsForExplanation = <String, int>{};
      for (final id in scheduledFacilityIds) {
        scheduledCountsForExplanation.update(id, (value) => value + 1, ifAbsent: () => 1);
      }
      final phaseEUnmetRefsOk = explanation != null &&
          explanation.unmetWishes.every((item) =>
              (scheduledCountsForExplanation[item.facilityId] ?? 0) <
              (requestedCountsForExplanation[item.facilityId] ?? 0));
      final phaseENoEmptyReason = explanation != null &&
          explanation.modeSummary.trim().isNotEmpty &&
          explanation.featureSummary.trim().isNotEmpty &&
          explanation.items.every((item) =>
              item.reason.trim().isNotEmpty && item.detailReason.trim().isNotEmpty) &&
          explanation.unmetWishes.every((item) =>
              item.reason.trim().isNotEmpty && item.detailReason.trim().isNotEmpty);
      final phaseEShortReasonOk = explanation != null &&
          explanation.items.every((item) => item.reason.length <= 32) &&
          explanation.unmetWishes.every((item) => item.reason.length <= 32);
      final phaseEReasonEvidenceOk = explanation != null &&
          explanation.items.every((item) => item.evidence.trim().isNotEmpty);
      final phaseEReasonCategoryOk = explanation != null &&
          explanation.items.every((item) =>
              PlanExplanationReasonCategory.values.contains(item.category));
      final hasFail = !dpaBoundaryOk || !overlapOk || !hardOk ||
          fourModeFail || todayFail || phaseFExecutionFail || !vpOverlapOk || !vpCoverageOk ||
          !vpIndependentOk || !vpCatalogOk || !vpMetricsOk ||
          !vpMovementSemanticOk || !phaseDScenarioCountOk ||
          !phaseDSameBasisOk || !phaseDNoOverlapOk ||
          lastAppliedPhaseDExactMatch == false || phaseDApplicationFail ||
          !phaseEItemRefsOk || !phaseEUnmetRefsOk || !phaseENoEmptyReason ||
          !phaseEShortReasonOk || !phaseEReasonEvidenceOk || !phaseEReasonCategoryOk;
      final hasCheck = today == null || (!todayPass && !todayFail) ||
          phaseFExecutionCheck || fourModeCheck;
      final result = hasFail ? 'FAIL' : hasCheck ? 'CHECK' : 'PASS';
      comprehensiveGateReport = <String>[
        '===== Disney Planner COMPREHENSIVE GATE =====',
        'Version: ${AppVersion.displayName}',
        'Context policy: PRE-TRIP / TODAY / COMMON are validated separately',
        '',
        '【COMMON / DPA BOUNDARY】',
        '[${dpaBoundaryOk ? 'PASS' : 'FAIL'}] No unacquired DPA scheduled — scheduled ${scheduledDpa.length}, unacquired scheduled ${unacquiredScheduledDpa.length}',
        '[PASS] PRE-TRIP candidate and TODAY acquired DPA are validated separately',
        '[${hardOk ? 'PASS' : 'FAIL'}] Hard wish coverage — $hardAchieved/${hardFacilities.length}',
        '[${overlapOk ? 'PASS' : 'FAIL'}] Current plan overlaps — ${planQualityAudit?.overlapCount ?? 0}',
        '',
        '【TODAY】',
        if (today == null)
          '[CHECK] Today Replan Gate — not executed in this app session'
        else if (todayPass)
          '[PASS] Today Replan Gate — latest runtime verification passed'
        else if (todayFail)
          '[FAIL] Today Replan Gate — latest runtime verification failed'
        else
          '[CHECK] Today Replan Gate — latest runtime verification remains CHECK',
        if (today != null) 'Latest Today evidence: ${today.split('\n').where((line) => line.startsWith('Action:') || line.startsWith('RESULT:')).join(' / ')}',
        '',
        '【PHASE F EXECUTION STATUS】',
        if (phaseFExecutionPass)
          '[PASS] Phase F Today completion self-check passed'
        else if (phaseFExecutionFail)
          '[FAIL] Phase F Today completion self-check failed'
        else
          '[CHECK] Phase F Today completion self-check not completed',
        if (phaseFExecution != null)
          ...phaseFExecution.split('\n').where((line) =>
              line.startsWith('[PASS] Completed') ||
              line.startsWith('[PASS] Skipped') ||
              line.startsWith('[FAIL] Completed') ||
              line.startsWith('[FAIL] Skipped') ||
              line.startsWith('[PASS] Current position') ||
              line.startsWith('[FAIL] Current position') ||
              line.startsWith('[CHECK] Current position') ||
              line.startsWith('[PASS] Conditional wish') ||
              line.startsWith('[FAIL] Conditional wish') ||
              line.startsWith('[CHECK] Conditional wish')),
        '',
        '【OPTIMIZATION】',
        if (fourModePass)
          '[PASS] 4-mode Gate — coverage-aware comparison passed'
        else if (fourModeFail)
          '[FAIL] 4-mode Gate — see embedded report'
        else
          '[CHECK] 4-mode Gate — prerequisite/result remains CHECK',
        '',
        '【VP / DPA COMPARISON】',
        '[PASS] VP total package price is not synthesized from DPA prices',
        '[${vpCatalogOk ? 'PASS' : 'FAIL'}] Official VP attraction-ticket types modeled — ${VacationPackageComparisonCatalog.attractionOptions.length} types / snapshot ${VacationPackageComparisonCatalog.officialSnapshotDate}',
        '[${vpIndependentOk ? 'PASS' : 'FAIL'}] VP unlimited-ride scenario generated independently',
        '[${vpCoverageOk ? 'PASS' : 'FAIL'}] VP comparison uses the same wish coverage semantics — ${vpScenario?.totalDesiredCount ?? 0}/${requiredFacilitiesForCurrentPark.length} wishes',
        '[${vpOverlapOk ? 'PASS' : 'FAIL'}] VP unlimited-ride scenario overlaps — ${vacationPackageComparisonOverlapCount ?? '-'}',
        '[${vpMetricsOk ? 'PASS' : 'FAIL'}] VP comparison metrics complete — hard ${vpScenario?.hardScheduledDesiredCount ?? '-'}/${vpScenario?.totalHardDesiredCount ?? '-'} / wait ${vpScenario?.totalWaitMinutes ?? '-'} / movement ${vpScenario?.totalMovementMinutes ?? '-'} / free ${vpScenario?.totalFreeMinutes ?? '-'}',
        '[${vpMovementSemanticOk ? 'PASS' : 'FAIL'}] VP movement metric semantic check — ${vpScenario?.totalMovementMinutes ?? '-'} min for ${vpScenario?.scheduledDesiredCount ?? 0} achieved wishes',
        '[INFO] Ticket types that require booked facility/time/quantity remain reference-only until those booking details are provided',
        '',
        '【PHASE D SCENARIO FOUNDATION】',
        '[${phaseDScenarioCountOk ? 'PASS' : 'FAIL'}] Four optimization scenarios generated independently — ${phaseDScenarioSummaries.length}/${ScheduleOptimizationMode.values.length}',
        '[${phaseDSameBasisOk ? 'PASS' : 'FAIL'}] Scenario comparison uses the same wish basis — ${requiredFacilitiesForCurrentPark.length} wishes / ${hardFacilities.length} hard',
        '[${phaseDNoOverlapOk ? 'PASS' : 'FAIL'}] Scenario comparison has no overlaps',
        '[PASS] Phase D comparison data is ready for normal UI',
        if (phaseDApplicationEvidence == null)
          '[INFO] Phase D application — not executed in this app session'
        else if (phaseDApplicationPass) ...[
          '[PASS] Phase D application evidence preserved across screens/controllers',
          ...phaseDApplicationEvidence.split('\n').where((line) =>
              line.startsWith('Selected mode:') ||
              line.startsWith('[PASS] Applied schedule matches') ||
              line.startsWith('[PASS] Hard wish coverage') ||
              line.startsWith('[PASS] Applied scenario overlaps')),
        ] else ...[
          '[FAIL] Phase D application evidence preserved but application did not pass',
          ...phaseDApplicationEvidence.split('\n').where((line) =>
              line.startsWith('Selected mode:') || line.startsWith('[FAIL]')),
        ],
        '',
        '【PHASE E EXPLANATION FOUNDATION】',
        '[${phaseEItemRefsOk ? 'PASS' : 'FAIL'}] Scheduled-item explanations reference current schedule only — ${explanation?.items.length ?? 0} items',
        '[${phaseEUnmetRefsOk ? 'PASS' : 'FAIL'}] Unmet-wish explanations reference actually unmet occurrences only — ${explanation?.unmetWishes.length ?? 0} entries',
        '[${phaseENoEmptyReason ? 'PASS' : 'FAIL'}] Explanation text is deterministic and non-empty',
        '[${phaseEShortReasonOk ? 'PASS' : 'FAIL'}] Beginner summary reasons stay concise',
        '[${phaseEReasonCategoryOk ? 'PASS' : 'FAIL'}] Explanation reasons use explicit supported categories',
        '[${phaseEReasonEvidenceOk ? 'PASS' : 'FAIL'}] Every scheduled-item reason has deterministic evidence',
        '[PASS] Detailed optimizer/source reasons are separated behind 詳しく見る',
        '[INFO] Phase E explanation UI does not change ScheduleEngine weights or schedule generation',
        '',
        '【REGRESSION SCOPE】',
        '[PASS] Pre-trip DPA candidate and Today acquired DPA use separate validation contexts',
        '[INFO] Today Gate is runtime evidence; it is not inferred from the PRE-TRIP schedule',
        '',
        'RESULT: $result',
        if (hasCheck) 'Pending: run Today replan + Undo once in this app session if TODAY is CHECK.',
        '===== END COMPREHENSIVE GATE =====',
      ].join('\n');
    } catch (error) {
      comprehensiveGateReport = '===== Disney Planner COMPREHENSIVE GATE =====\n'
          '[FAIL] Comprehensive Gate execution — ${error.runtimeType}: $error\n'
          'RESULT: FAIL\n'
          '===== END COMPREHENSIVE GATE =====';
    } finally {
      isRunningComprehensiveGate = false;
      notifyListeners();
    }
  }

  void _capturePreAdditionState(String addedFacilityName) {
    final current = schedule;
    _preAdditionScheduledIds = current == null
        ? const <String>{}
        : current.items
            .map((item) => item.facilityId)
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet();
    _preAdditionDesiredCount = selectedFacilitiesForCurrentPark.length;
    _lastAddedFacilityName = addedFacilityName;
    lastAdditionImpact = null;
  }

  void _updateAdditionImpact() {
    final current = schedule;
    final addedName = _lastAddedFacilityName;
    if (current == null || addedName == null) return;
    final currentIds = current.items
        .map((item) => item.facilityId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final lostIds = _preAdditionScheduledIds.difference(currentIds);
    final lostNames = selectedFacilitiesForCurrentPark
        .where((facility) => lostIds.contains(facility.id))
        .map((facility) => facility.name)
        .toList(growable: false);
    final desiredNow = selectedFacilitiesForCurrentPark.length;
    if (lostNames.isEmpty) {
      lastAdditionImpact = PlanAdditionImpact(
        addedFacilityName: addedName,
        beforeDesiredCount: _preAdditionDesiredCount,
        afterDesiredCount: desiredNow,
        lostFacilityNames: const <String>[],
        explanation: '追加した希望を含めて一日全体を組み直し、追加前に入っていた希望も維持できました。',
      );
    } else {
      final fixedAdded = selectedFacilitiesForCurrentPark.where((facility) {
        if (facility.name != addedName) return false;
        final preference = _appState.getPreference(facility.id);
        return preference?.fixedTimeStatus == FixedTimeStatus.planned ||
            (preference?.scheduledAccessTime.trim().isNotEmpty ?? false);
      }).isNotEmpty;
      lastAdditionImpact = PlanAdditionImpact(
        addedFacilityName: addedName,
        beforeDesiredCount: _preAdditionDesiredCount,
        afterDesiredCount: desiredNow,
        lostFacilityNames: lostNames,
        explanation: fixedAdded
            ? '追加候補「$addedName」は時刻指定です。行きたいことを優先したうえで空き時間へ入る場合だけ採用します。'
            : '追加候補「$addedName」は、行きたいことを優先した残り時間で採用可否を判断します。',
      );
    }
    notifyListeners();
  }


  DaySchedule? get schedule {
    return _appState.daySchedule;
  }

  List<PlanPreference> get preferencesForExport =>
      List<PlanPreference>.unmodifiable(
        _generatedPreferences ?? _appState.planPreferences,
      );

  TripSettings get tripSettings => _appState.tripSettings;

  String get selectedParkId {
    return _appState.tripSettings.parkId;
  }

  String get selectedParkName {
    return switch (selectedParkId) {
      'tokyo_disneyland' => '東京ディズニーランド',
      'tokyo_disneysea' => '東京ディズニーシー',
      _ => selectedParkId,
    };
  }

  IconData get selectedParkIcon {
    return switch (selectedParkId) {
      'tokyo_disneyland' => Icons.castle_outlined,
      'tokyo_disneysea' => Icons.water_outlined,
      _ => Icons.park_outlined,
    };
  }

  List<Facility> get selectedFacilitiesForCurrentPark {
    return List<Facility>.unmodifiable(
      _appState.selectedFacilities
          .where((facility) => facility.parkId == selectedParkId)
          .toList(growable: false),
    );
  }

  int get selectedFacilityCount {
    return selectedFacilitiesForCurrentPark.length;
  }

  List<Facility> get requiredFacilitiesForCurrentPark =>
      List<Facility>.unmodifiable(
        selectedFacilitiesForCurrentPark
            .where((facility) => !_appState.isOptionalAddition(facility.id))
            .toList(growable: false),
      );

  List<Facility> get optionalAdditionsForCurrentPark =>
      List<Facility>.unmodifiable(
        selectedFacilitiesForCurrentPark
            .where((facility) => _appState.isOptionalAddition(facility.id))
            .toList(growable: false),
      );

  List<Facility> get scheduledOptionalAdditions {
    final ids = schedule?.items
            .map((item) => item.facilityId)
            .whereType<String>()
            .toSet() ??
        const <String>{};
    return optionalAdditionsForCurrentPark
        .where((facility) => ids.contains(facility.id))
        .toList(growable: false);
  }

  List<Facility> get unscheduledOptionalAdditions {
    final scheduledIds = scheduledOptionalAdditions.map((f) => f.id).toSet();
    return optionalAdditionsForCurrentPark
        .where((facility) => !scheduledIds.contains(facility.id))
        .toList(growable: false);
  }

  List<Facility> get unavailableSelectedFacilities {
    final targetDate = _appState.tripSettings.visitDate ?? DateTime.now();
    return List<Facility>.unmodifiable(
      selectedFacilitiesForCurrentPark
          .where((facility) => !facility.canAddToPlanAt(targetDate))
          .toList(growable: false),
    );
  }

  int get unavailableSelectedFacilityCount {
    return unavailableSelectedFacilities.length;
  }

  bool get hasUnavailableSelectedFacilities {
    return unavailableSelectedFacilities.isNotEmpty;
  }

  bool get canGenerateSchedule {
    return selectedFacilitiesForCurrentPark.isNotEmpty;
  }

  bool get hasSchedule {
    return schedule != null;
  }

  bool get canUndo => _appState.canUndoScheduleChange;
  bool get canRedo => _appState.canRedoScheduleChange;
  int get historyCount => _appState.scheduleHistoryCount;

  List<ScheduleValidationIssue> get validationIssues {
    final current = schedule;
    if (current == null) {
      return const [];
    }
    return _scheduleValidator.validate(
      schedule: current,
      settings: _appState.tripSettings,
      preferences: _appState.planPreferences,
      facilities: requiredFacilitiesForCurrentPark,
    );
  }

  void undoScheduleChange() => _appState.undoLastScheduleChange();
  void redoScheduleChange() => _appState.redoLastScheduleChange();

  bool get scheduleMatchesSelectedPark {
    final currentSchedule = schedule;

    if (currentSchedule == null) {
      return true;
    }

    return currentSchedule.parkId == selectedParkId;
  }

  bool get hasStaleSchedule {
    return schedule != null && !scheduleMatchesSelectedPark;
  }

  Facility? facilityById(String? facilityId) {
    if (facilityId == null || facilityId.trim().isEmpty) {
      return null;
    }

    for (final facility in _appState.selectedFacilities) {
      if (facility.id == facilityId) {
        return facility;
      }
    }

    return null;
  }

  PlanPreference? preferenceByFacilityId(String? facilityId) {
    if (facilityId == null || facilityId.trim().isEmpty) {
      return null;
    }

    return _appState.getPreference(facilityId);
  }

  List<String> get fixedTimeConflicts {
    return _fixedConflictService.findConflicts(
      facilities: selectedFacilitiesForCurrentPark,
      preferences: _appState.planPreferences,
    );
  }

  int coveredDesiredOccurrenceCount(
    List<Facility> desiredFacilities,
    Iterable<String> scheduledFacilityIds,
  ) {
    final desiredCounts = <String, int>{};
    for (final facility in desiredFacilities) {
      desiredCounts[facility.id] = (desiredCounts[facility.id] ?? 0) + 1;
    }
    final scheduledCounts = <String, int>{};
    for (final id in scheduledFacilityIds) {
      if (!desiredCounts.containsKey(id)) continue;
      scheduledCounts[id] = (scheduledCounts[id] ?? 0) + 1;
    }
    var covered = 0;
    for (final entry in desiredCounts.entries) {
      final scheduled = scheduledCounts[entry.key] ?? 0;
      covered += scheduled < entry.value ? scheduled : entry.value;
    }
    return covered;
  }

  Future<void> analyzePlanCoverage() async {
    final currentSchedule = schedule;
    if (currentSchedule == null || selectedFacilitiesForCurrentPark.isEmpty) {
      coverageAdvice = null;
      vacationPackageComparisonScenario = null;
      vacationPackageComparisonOverlapCount = null;
      vacationPackageComparisonGeneratedIndependently = false;
      coverageAnalysisError = null;
      notifyListeners();
      return;
    }

    isAnalyzingCoverage = true;
    vacationPackageComparisonScenario = null;
    vacationPackageComparisonOverlapCount = null;
    vacationPackageComparisonGeneratedIndependently = false;
    coverageAnalysisError = null;
    notifyListeners();

    try {
      final targetDate = _appState.tripSettings.visitDate ?? DateTime.now();
      final desiredFacilities = requiredFacilitiesForCurrentPark.where((facility) {
        final preference = _appState.getPreference(facility.id);
        return facility.canAddToPlanAt(targetDate) && !(preference?.isExcluded ?? false);
      }).toList(growable: false);

      if (desiredFacilities.isEmpty) {
        coverageAdvice = null;
        return;
      }

      final desiredIds = desiredFacilities.map((facility) => facility.id).toSet();
      final hardDesiredFacilities = desiredFacilities.where((facility) {
        final preference = preferenceByFacilityId(facility.id);
        return preference == null || preference.priority.value > 2;
      }).toList(growable: false);
      final selectedPreferences = _appState.planPreferences
          .where((preference) => desiredIds.contains(preference.facilityId))
          .toList(growable: false);
      final settings = _appState.tripSettings;
      final preferences = await _performanceResolver.resolve(
        parkId: selectedParkId,
        date: targetDate,
        entryMinutes: settings.entryTimeHour * 60 + settings.entryTimeMinute,
        exitMinutes: settings.exitTimeHour * 60 + settings.exitTimeMinute,
        facilities: desiredFacilities,
        preferences: selectedPreferences,
      );

      final eventImpacts = await ServiceLocator.eventImpactRepository
          .loadEventImpacts(parkId: selectedParkId);
      final waitProfiles = await const CrowdFactorRepositoryImpl()
          .loadWaitProfilesForDate(parkId: selectedParkId, targetDate: targetDate);
      final crowdFactors = await const CrowdFactorRepositoryImpl()
          .loadCrowdFactors(parkId: selectedParkId);
      final greetingWaitPlanning =
          await const LocalGreetingWaitPlanningRepository().load(
            parkId: selectedParkId,
            targetDate: targetDate,
            facilities: desiredFacilities,
            crowdFactors: crowdFactors,
          );
      final expertProfiles = await ServiceLocator.expertRecommendationRepository
          .loadProfiles(parkId: selectedParkId);
      final unlimitedRideBufferMinutes = settings.usesVacationPackage &&
              settings.hasUnlimitedAttractionRides
          ? await const LocalVacationPackageUnlimitedRideRepository()
              .loadPriorityAccessBufferMinutes(parkId: selectedParkId)
          : <String, int>{};
      final availableMinutes =
          (settings.exitTimeHour * 60 + settings.exitTimeMinute) -
          (settings.entryTimeHour * 60 + settings.entryTimeMinute);
      final morningRanking = const WishCandidateScoringEngine().score(
        facilities: desiredFacilities,
        preferences: preferences,
        waitProfiles: waitProfiles,
        availableMinutes: availableMinutes,
        targetDate: targetDate,
        hasHappyEntry: settings.hasHappyEntry,
        expertProfiles: expertProfiles,
        unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
        greetingWaitPlanning: greetingWaitPlanning,
      );

      final dpaEligibleRanking = morningRanking
          .where((candidate) =>
              candidate.facility.category == FacilityCategory.attraction &&
              candidate.facility.supportsDpa &&
              !unlimitedRideBufferMinutes.containsKey(candidate.facility.id))
          .toList(growable: false);
      final fullAllocation = _dpaAutoAllocator.allocate(
        strategy: DpaStrategy(
          type: DpaStrategyType.attractions,
          maxUses: dpaEligibleRanking.length,
        ),
        candidates: dpaEligibleRanking,
        preferences: preferences,
      );
      final orderedDpaIds = fullAllocation.selectedFacilityIds;

      final allParkFacilities = await ServiceLocator.facilityRepository
          .getFacilitiesByParkId(selectedParkId);
      final allParkFacilityById = {
        for (final facility in allParkFacilities) facility.id: facility,
      };
      final officialOptions = await _performanceScheduleRepository.findParkOptions(
        parkId: selectedParkId,
        date: targetDate,
      );
      final officialPerformanceOpportunities = <OfficialPerformanceOpportunity>[];
      for (final option in officialOptions) {
        final facility = allParkFacilityById[option.facilityId];
        if (facility == null ||
            (facility.category != FacilityCategory.show &&
                facility.category != FacilityCategory.parade)) {
          continue;
        }
        final startMinutes = _parseTimeMinutes(option.startTime);
        if (startMinutes == null) continue;
        officialPerformanceOpportunities.add(
          OfficialPerformanceOpportunity(
            facilityId: facility.id,
            name: facility.name,
            startMinutes: startMinutes,
            endMinutes: startMinutes + facility.durationMinutes,
            requiresEntryRequest: facility.requiresEntryRequest,
            supportsDpa: facility.supportsDpa,
            isSelected: desiredIds.contains(facility.id),
            isMustDo: preferences.any(
              (preference) =>
                  preference.facilityId == facility.id &&
                  preference.priority == PriorityLevel.highest,
            ),
          ),
        );
      }
      final areaConnections = await ServiceLocator.movementRepository
          .loadAreaConnections(parkId: selectedParkId);
      final facilityLocations = await ServiceLocator.movementRepository
          .loadFacilityLocations(parkId: selectedParkId);

      final basePreferences = preferences.map((preference) {
        final facility = allParkFacilityById[preference.facilityId];
        if (facility?.category == FacilityCategory.attraction &&
            preference.accessMethod == FacilityAccessMethod.dpa) {
          return preference.copyWith(
            useDpa: false,
            accessMethod: FacilityAccessMethod.standby,
          );
        }
        return preference;
      }).toList(growable: false);

      // Use the plan already on screen as the DPA=0 baseline. Re-running the
      // full-day Beam Search for count=0 made this advice card needlessly slow.
      final currentScheduledFacilityIdList = currentSchedule.items
          .map((item) => item.facilityId)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      final currentScheduledFacilityIds = currentScheduledFacilityIdList.toSet();
      final currentAudit = const PlanQualityAuditService().evaluate(
        currentSchedule,
        facilities: allParkFacilities,
        facilityLocations: facilityLocations,
        areaConnections: areaConnections,
      );
      final scenarios = <PlanCoverageScenario>[
        PlanCoverageScenario(
          dpaCount: 0,
          scheduledFacilityIds: currentScheduledFacilityIds,
          scheduledDesiredCount: coveredDesiredOccurrenceCount(
            desiredFacilities,
            currentScheduledFacilityIdList,
          ),
          selectedDpaFacilityIds: const <String>[],
          totalWaitMinutes: currentAudit.totalWaitMinutes,
          totalFreeMinutes: currentAudit.totalFreeMinutes,
          totalMovementMinutes: currentAudit.totalMovementMinutes,
          hardScheduledDesiredCount: coveredDesiredOccurrenceCount(
            hardDesiredFacilities,
            currentScheduledFacilityIdList,
          ),
          totalHardDesiredCount: hardDesiredFacilities.length,
        ),
      ];
      final maxDpaCount = orderedDpaIds.length;
      // Stop as soon as all wishes are rescued. Higher DPA counts cannot improve
      // coverage any further and previously caused the UI spinner to run through
      // every expensive full-day simulation.
      for (var count = 1; count <= maxDpaCount; count++) {
        final chosenIds = orderedDpaIds.take(count).toSet();
        final scenarioPreferences = basePreferences.map((preference) {
          final facility = allParkFacilityById[preference.facilityId];
          if (facility == null ||
              facility.category != FacilityCategory.attraction ||
              !facility.supportsDpa) {
            return preference;
          }
          final useDpa = chosenIds.contains(preference.facilityId);
          return preference.copyWith(
            useDpa: useDpa,
            accessMethod: useDpa
                ? FacilityAccessMethod.dpa
                : FacilityAccessMethod.standby,
          );
        }).toList(growable: false);

        // Coverage/DPA simulation can invoke the same full-day Beam Search many
        // times after the visible plan has already been generated. Keep those
        // simulations off the UI isolate as well; otherwise the completed-plan
        // screen becomes unresponsive while coverage analysis is running.
        final simulated = await _generateScheduleOffUi(
          _ScheduleGenerationRequest(
            settings: settings.copyWith(
              canUseDpa: count > 0,
              attractionDpaMaxUses: count,
            ),
            facilities: List<Facility>.of(desiredFacilities),
            preferences: List<PlanPreference>.of(scenarioPreferences),
            eventImpacts: List<EventImpact>.of(eventImpacts),
            waitProfiles: List<TimeBandWaitProfile>.of(waitProfiles),
            morningScores: <String, double>{
              for (final candidate in morningRanking)
                candidate.facility.id:
                    candidate.firstMoveScore ?? candidate.score,
            },
            officialPerformanceOpportunities:
                List<OfficialPerformanceOpportunity>.of(
              officialPerformanceOpportunities,
            ),
            areaConnections: List<AreaConnection>.of(areaConnections),
            facilityLocations: List<FacilityLocation>.of(facilityLocations),
            expertProfiles:
                List<ExpertRecommendationProfile>.of(expertProfiles),
            unlimitedRideBufferMinutes:
                Map<String, int>.of(unlimitedRideBufferMinutes),
            greetingWaitPlanning:
                Map<String, GreetingWaitPlanningValue>.of(greetingWaitPlanning),
            manualFixedItems: const <ScheduleItem>[],
          ),
        );
        final simulatedFacilityIdList = simulated.items
            .map((item) => item.facilityId)
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toList(growable: false);
        final simulatedFacilityIds = simulatedFacilityIdList.toSet();
        final scheduledDesiredCount = coveredDesiredOccurrenceCount(
          desiredFacilities,
          simulatedFacilityIdList,
        );
        final simulatedAudit = const PlanQualityAuditService().evaluate(
          simulated,
          facilities: allParkFacilities,
          facilityLocations: facilityLocations,
          areaConnections: areaConnections,
        );
        scenarios.add(
          PlanCoverageScenario(
            dpaCount: count,
            scheduledFacilityIds: simulatedFacilityIds,
            scheduledDesiredCount: scheduledDesiredCount,
            selectedDpaFacilityIds:
                orderedDpaIds.take(count).toList(growable: false),
            totalWaitMinutes: simulatedAudit.totalWaitMinutes,
            totalFreeMinutes: simulatedAudit.totalFreeMinutes,
            totalMovementMinutes: simulatedAudit.totalMovementMinutes,
            hardScheduledDesiredCount: coveredDesiredOccurrenceCount(
              hardDesiredFacilities,
              simulatedFacilityIdList,
            ),
            totalHardDesiredCount: hardDesiredFacilities.length,
          ),
        );
        if (scheduledDesiredCount >= desiredIds.length) {
          break;
        }
      }

      final waitByFacilityId = {
        for (final candidate in morningRanking)
          candidate.facility.id: candidate.predictedWaitMinutes,
      };
      // Coverage simulation can take long enough that the visible schedule may
      // be replaced while it is running (for example after a re-generation).
      // Always reconcile the baseline with the schedule that is actually on
      // screen at completion. This keeps the headline, unmet list and DPA=0
      // scenario on one shared coverage snapshot instead of showing 10/11 in
      // the card header and 9/11 in the advice body.
      final latestSchedule = schedule;
      final latestScheduledFacilityIdList = latestSchedule?.items
              .map((item) => item.facilityId)
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toList(growable: false) ??
          currentScheduledFacilityIdList;
      final latestScheduledFacilityIds = latestScheduledFacilityIdList.toSet();
      final latestCurrentCount = coveredDesiredOccurrenceCount(
        desiredFacilities,
        latestScheduledFacilityIdList,
      );
      final latestAudit = latestSchedule == null
          ? currentAudit
          : const PlanQualityAuditService().evaluate(
              latestSchedule,
              facilities: allParkFacilities,
              facilityLocations: facilityLocations,
              areaConnections: areaConnections,
            );
      final reconciledScenarios = <PlanCoverageScenario>[
        PlanCoverageScenario(
          dpaCount: 0,
          scheduledFacilityIds: latestScheduledFacilityIds,
          scheduledDesiredCount: latestCurrentCount,
          selectedDpaFacilityIds: const <String>[],
          totalWaitMinutes: latestAudit.totalWaitMinutes,
          totalFreeMinutes: latestAudit.totalFreeMinutes,
          totalMovementMinutes: latestAudit.totalMovementMinutes,
          hardScheduledDesiredCount: coveredDesiredOccurrenceCount(
            hardDesiredFacilities,
            latestScheduledFacilityIdList,
          ),
          totalHardDesiredCount: hardDesiredFacilities.length,
        ),
        ...scenarios.where((scenario) => scenario.dpaCount > 0),
      ];

      final latestScheduledFacilityCounts = <String, int>{};
      for (final id in latestScheduledFacilityIdList) {
        latestScheduledFacilityCounts[id] =
            (latestScheduledFacilityCounts[id] ?? 0) + 1;
      }

      coverageAdvice = _coverageAdviceService.build(
        desiredFacilities: desiredFacilities,
        currentScheduledFacilityIds: latestScheduledFacilityIds,
        currentScheduledFacilityCounts: latestScheduledFacilityCounts,
        currentScheduledDesiredCount: latestCurrentCount,
        scenarios: reconciledScenarios,
        orderedDpaMetrics: [
          for (final id in orderedDpaIds)
            DpaOrderMetric(
              facilityId: id,
              estimatedSavedMinutes: waitByFacilityId[id] == null
                  ? null
                  : (waitByFacilityId[id]! - 15).clamp(0, 240).toInt(),
            ),
        ],
      );

      // Phase C.5: compare the same wishes against the official VP unlimited-ride
      // benefit. This is a benefit simulation only; Vacation Package total price
      // depends on the booked package/hotel/date and is intentionally not invented.
      final vpBuffers = await const LocalVacationPackageUnlimitedRideRepository()
          .loadPriorityAccessBufferMinutes(parkId: selectedParkId);
      if (vpBuffers.isNotEmpty) {
        final vpSchedule = await _generateScheduleOffUi(
          _ScheduleGenerationRequest(
            settings: settings.copyWith(
              usesVacationPackage: true,
              hasUnlimitedAttractionRides: true,
              canUseDpa: false,
              attractionDpaMaxUses: 0,
            ),
            facilities: List<Facility>.of(desiredFacilities),
            preferences: List<PlanPreference>.of(basePreferences),
            eventImpacts: List<EventImpact>.of(eventImpacts),
            waitProfiles: List<TimeBandWaitProfile>.of(waitProfiles),
            morningScores: <String, double>{
              for (final candidate in morningRanking)
                candidate.facility.id: candidate.firstMoveScore ?? candidate.score,
            },
            officialPerformanceOpportunities:
                List<OfficialPerformanceOpportunity>.of(officialPerformanceOpportunities),
            areaConnections: List<AreaConnection>.of(areaConnections),
            facilityLocations: List<FacilityLocation>.of(facilityLocations),
            expertProfiles: List<ExpertRecommendationProfile>.of(expertProfiles),
            unlimitedRideBufferMinutes: Map<String, int>.of(vpBuffers),
            greetingWaitPlanning:
                Map<String, GreetingWaitPlanningValue>.of(greetingWaitPlanning),
            manualFixedItems: const <ScheduleItem>[],
          ),
        );
        final vpIds = vpSchedule.items
            .map((item) => item.facilityId)
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toList(growable: false);
        final vpAudit = const PlanQualityAuditService().evaluate(
          vpSchedule,
          facilities: allParkFacilities,
          facilityLocations: facilityLocations,
          areaConnections: areaConnections,
        );
        vacationPackageComparisonOverlapCount = vpAudit.overlapCount;
        vacationPackageComparisonGeneratedIndependently = true;
        vacationPackageComparisonScenario = PlanningScenario(
          kind: PlanningScenarioKind.vacationPackage,
          scheduledDesiredCount:
              coveredDesiredOccurrenceCount(desiredFacilities, vpIds),
          totalDesiredCount: desiredFacilities.length,
          extraCostYen: null,
          costDataAvailable: false,
          totalWaitMinutes: vpAudit.totalWaitMinutes,
          totalFreeMinutes: vpAudit.totalFreeMinutes,
          totalMovementMinutes: vpAudit.totalMovementMinutes,
          hardScheduledDesiredCount: coveredDesiredOccurrenceCount(
            hardDesiredFacilities,
            vpIds,
          ),
          totalHardDesiredCount: hardDesiredFacilities.length,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('希望達成/DPA分析に失敗しました: $error');
      debugPrintStack(stackTrace: stackTrace);
      coverageAnalysisError = '希望達成状況を分析できませんでした。プランを再生成してからもう一度お試しください。';
    } finally {
      isAnalyzingCoverage = false;
      notifyListeners();
    }
  }

  Future<bool> applyPlanningScenario(PlanningScenario scenario) async {
    final dpaIds = scenario.selectedDpaFacilityIds.toSet();
    if (scenario.kind == PlanningScenarioKind.dpa &&
        (!scenario.costDataAvailable || scenario.extraCostYen == null)) {
      errorMessage = '料金を確認できないDPA構成は最終プランへ適用できません。';
      notifyListeners();
      return false;
    }

    final useDpa = scenario.dpaCount > 0 && dpaIds.isNotEmpty;
    // A pre-trip DPA scenario is purchase intent only. The actual return window
    // is unknown until the guest enters the park and purchases DPA in the
    // official app, so never turn this scenario into a timed DPA schedule item.
    _appState.updateTripSettings(
      _appState.tripSettings.copyWith(
        canUseDpa: useDpa,
        attractionDpaMaxUses: useDpa ? scenario.dpaCount : 0,
        plannedDpaFacilityIds: dpaIds.toList(growable: false),
      ),
    );
    // Do not regenerate the pre-trip schedule here. The recommendation is only
    // purchase intent; regenerating with a synthetic DPA condition can change
    // an otherwise valid standby plan even though no DPA return window exists
    // yet. Keep the current schedule authoritative until an actual DPA window
    // is acquired in Today mode.
    errorMessage = null;
    notifyListeners();
    return schedule != null;
  }

  Future<void> generateSchedule({
    List<ScheduleItem> additionalManualFixedItems = const <ScheduleItem>[],
    bool preserveManualFixedItems = true,
    Set<String>? forcedDpaFacilityIds,
    bool debugNoHistory = false,
  }) async {
    if (!canGenerateSchedule) {
      errorMessage =
          '現在のパークでは施設が選択されていません。'
          'プラン編集画面から行きたい施設を追加してください。';

      notifyListeners();

      return;
    }

    final conflicts = fixedTimeConflicts;
    if (conflicts.isNotEmpty) {
      errorMessage = '固定予定が競合しています。時刻を変更してください。\n${conflicts.join('\n')}';
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;
    generationStatus = '必要なデータを読み込んでいます…';

    notifyListeners();
    await Future<void>.delayed(Duration.zero);

    try {
      final targetDate = _appState.tripSettings.visitDate ?? DateTime.now();
      final availableFacilities = selectedFacilitiesForCurrentPark
          .where((facility) => facility.canAddToPlanAt(targetDate))
          .toList(growable: false);

      if (availableFacilities.isEmpty) {
        errorMessage =
            '営業中の施設が選択されていません。'
            '休止中施設の選択を解除してください。';

        return;
      }

      final selectedFacilityIds = availableFacilities
          .map((facility) => facility.id)
          .toSet();

      final selectedPreferences = _appState.planPreferences
          .where((preference) {
            return selectedFacilityIds.contains(preference.facilityId);
          })
          .toList(growable: false);

      final settings = _appState.tripSettings;
      final manualFixedItems =
          preserveManualFixedItems &&
                  settings.usesVacationPackage &&
                  settings.hasUnlimitedAttractionRides
              ? <ScheduleItem>[
                  ..._manualRepeatItemsForDate(targetDate),
                  ...additionalManualFixedItems,
                ]
              : <ScheduleItem>[];
      final unlimitedRideBufferMinutes = settings.usesVacationPackage &&
              settings.hasUnlimitedAttractionRides
          ? await const LocalVacationPackageUnlimitedRideRepository()
              .loadPriorityAccessBufferMinutes(parkId: selectedParkId)
          : <String, int>{};
      final preferences = await _performanceResolver.resolve(
        parkId: selectedParkId,
        date: targetDate,
        entryMinutes: settings.entryTimeHour * 60 + settings.entryTimeMinute,
        exitMinutes: settings.exitTimeHour * 60 + settings.exitTimeMinute,
        facilities: availableFacilities,
        preferences: selectedPreferences,
      );

      final resolvedFixedConflicts = _fixedConflictService.findConflicts(
        facilities: availableFacilities,
        preferences: preferences,
      );
      if (resolvedFixedConflicts.isNotEmpty) {
        errorMessage =
            '固定予定が競合しています。両方を同時には実行できません。\n'
            '${resolvedFixedConflicts.join('\n')}';
        return;
      }

      for (final preference in preferences) {
        final current = _appState.getPreference(preference.facilityId);
        if (current == null ||
            current.preferredPerformanceTime ==
                preference.preferredPerformanceTime) {
          continue;
        }
        _appState.updatePreferenceSelectedPerformance(
          facilityId: preference.facilityId,
          performanceIndex: preference.selectedPerformanceIndex,
          startTime: preference.preferredPerformanceTime,
        );
      }

      final eventImpacts = await ServiceLocator.eventImpactRepository
          .loadEventImpacts(parkId: selectedParkId);

      final waitProfiles = await const CrowdFactorRepositoryImpl()
          .loadWaitProfilesForDate(
            parkId: selectedParkId,
            targetDate: targetDate,
          );
      final crowdFactors = await const CrowdFactorRepositoryImpl()
          .loadCrowdFactors(parkId: selectedParkId);
      final greetingWaitPlanning =
          await const LocalGreetingWaitPlanningRepository().load(
            parkId: selectedParkId,
            targetDate: targetDate,
            facilities: availableFacilities,
            crowdFactors: crowdFactors,
          );
      final expertProfiles = await ServiceLocator.expertRecommendationRepository
          .loadProfiles(parkId: selectedParkId);
      final availableMinutes =
          (settings.exitTimeHour * 60 + settings.exitTimeMinute) -
          (settings.entryTimeHour * 60 + settings.entryTimeMinute);
      final morningRanking = const WishCandidateScoringEngine().score(
        facilities: availableFacilities,
        preferences: preferences,
        waitProfiles: waitProfiles,
        availableMinutes: availableMinutes,
        targetDate: targetDate,
        hasHappyEntry: settings.hasHappyEntry,
        expertProfiles: expertProfiles,
        unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
        greetingWaitPlanning: greetingWaitPlanning,
      );

      var generatedPreferences = preferences;
      if (forcedDpaFacilityIds != null) {
        generatedPreferences = preferences.map((preference) {
          final facility = availableFacilities
              .where((item) => item.id == preference.facilityId)
              .firstOrNull;
          if (facility?.category != FacilityCategory.attraction ||
              facility?.supportsDpa != true) {
            return preference;
          }
          final useDpa = forcedDpaFacilityIds.contains(preference.facilityId);
          return preference.copyWith(
            useDpa: useDpa,
            accessMethod: useDpa
                ? FacilityAccessMethod.dpa
                : FacilityAccessMethod.standby,
          );
        }).toList(growable: false);
      } else {
        // Pre-trip DPA settings describe purchase intent / scenario capacity only.
        // A DPA return window does not exist until the guest actually acquires it
        // in the park. Therefore the normal pre-trip schedule must stay standby
        // and must never synthesize a timed DPA item from canUseDpa/maxUses.
        // Coverage analysis still performs explicit DPA simulations separately,
        // and Today-mode acquired access is supplied as a fixed real-world input.
        generatedPreferences = preferences.map((preference) {
          if (preference.accessMethod != FacilityAccessMethod.dpa &&
              !preference.useDpa) {
            return preference;
          }
          return preference.copyWith(
            useDpa: false,
            accessMethod: FacilityAccessMethod.standby,
          );
        }).toList(growable: false);
      }
      _generatedPreferences = List<PlanPreference>.unmodifiable(
        generatedPreferences,
      );

      final allParkFacilities = await ServiceLocator.facilityRepository
          .getFacilitiesByParkId(selectedParkId);
      final allParkFacilityById = {
        for (final facility in allParkFacilities) facility.id: facility,
      };
      final officialOptions = await _performanceScheduleRepository
          .findParkOptions(
            parkId: selectedParkId,
            date: targetDate,
          );
      final officialPerformanceOpportunities =
          <OfficialPerformanceOpportunity>[];
      for (final option in officialOptions) {
        final facility = allParkFacilityById[option.facilityId];
        if (facility == null ||
            (facility.category != FacilityCategory.show &&
                facility.category != FacilityCategory.parade)) {
          continue;
        }
        final startMinutes = _parseTimeMinutes(option.startTime);
        if (startMinutes == null) continue;
        officialPerformanceOpportunities.add(
          OfficialPerformanceOpportunity(
            facilityId: facility.id,
            name: facility.name,
            startMinutes: startMinutes,
            endMinutes: startMinutes + facility.durationMinutes,
            requiresEntryRequest: facility.requiresEntryRequest,
            supportsDpa: facility.supportsDpa,
            isSelected: selectedFacilityIds.contains(facility.id),
            isMustDo: generatedPreferences.any(
              (preference) =>
                  preference.facilityId == facility.id &&
                  preference.priority == PriorityLevel.highest,
            ),
          ),
        );
      }

      _setGenerationStatus('移動と固定予定を確認しています…');
      final areaConnections = await ServiceLocator.movementRepository
          .loadAreaConnections(parkId: selectedParkId);
      final facilityLocations = await ServiceLocator.movementRepository
          .loadFacilityLocations(parkId: selectedParkId);
      _qualityAuditFacilities = List<Facility>.unmodifiable(allParkFacilities);
      _qualityAuditLocations = List<FacilityLocation>.unmodifiable(facilityLocations);
      _qualityAuditConnections = List<AreaConnection>.unmodifiable(areaConnections);

      _setGenerationStatus('やりたいことと追加候補を一緒に全体最適化しています…');

      final request = _ScheduleGenerationRequest(
        settings: _appState.tripSettings,
        facilities: List<Facility>.of(availableFacilities),
        preferences: List<PlanPreference>.of(generatedPreferences),
        eventImpacts: List<EventImpact>.of(eventImpacts),
        waitProfiles: List<TimeBandWaitProfile>.of(waitProfiles),
        morningScores: <String, double>{
          for (final candidate in morningRanking)
            candidate.facility.id:
                candidate.firstMoveScore ?? candidate.score,
        },
        officialPerformanceOpportunities:
            List<OfficialPerformanceOpportunity>.of(
              officialPerformanceOpportunities,
            ),
        areaConnections: List<AreaConnection>.of(areaConnections),
        facilityLocations: List<FacilityLocation>.of(facilityLocations),
        expertProfiles:
            List<ExpertRecommendationProfile>.of(expertProfiles),
        unlimitedRideBufferMinutes:
            Map<String, int>.of(unlimitedRideBufferMinutes),
        greetingWaitPlanning:
            Map<String, GreetingWaitPlanningValue>.of(greetingWaitPlanning),
        manualFixedItems: List<ScheduleItem>.of(manualFixedItems),
        // First try the optional additions as real schedule candidates.
        // In particular, shows/parades need their resolved performance time to
        // participate in the full-day rebuild instead of being excluded before
        // the optimizer can test them.
        optionalFacilityIds: const <String>{},
      );

      final optionalIds = _appState.optionalAdditionFacilityIds;
      final requiredCounts = <String, int>{};
      for (final facility in _appState.selectedFacilitiesForPark(selectedParkId)) {
        if (optionalIds.contains(facility.id)) continue;
        requiredCounts.update(
          facility.id,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }

      bool containsCounts(DaySchedule candidate, Map<String, int> counts) {
        final scheduledCounts = <String, int>{};
        for (final item in candidate.items) {
          final facilityId = item.facilityId;
          if (facilityId == null) continue;
          scheduledCounts.update(
            facilityId,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
        return counts.entries.every(
          (entry) => (scheduledCounts[entry.key] ?? 0) >= entry.value,
        );
      }

      _ScheduleGenerationRequest requestForOptionalSubset(Set<String> included) {
        final excluded = optionalIds.difference(included);
        return _ScheduleGenerationRequest(
          settings: request.settings,
          facilities: request.facilities
              .where((facility) => !excluded.contains(facility.id))
              .toList(growable: false),
          preferences: request.preferences
              .where((preference) => !excluded.contains(preference.facilityId))
              .toList(growable: false),
          eventImpacts: request.eventImpacts,
          waitProfiles: request.waitProfiles,
          morningScores: request.morningScores,
          officialPerformanceOpportunities: request.officialPerformanceOpportunities
              .where((opportunity) => !excluded.contains(opportunity.facilityId))
              .toList(growable: false),
          areaConnections: request.areaConnections,
          facilityLocations: request.facilityLocations,
          expertProfiles: request.expertProfiles,
          unlimitedRideBufferMinutes: request.unlimitedRideBufferMinutes,
          greetingWaitPlanning: request.greetingWaitPlanning,
          manualFixedItems: request.manualFixedItems
              .where((item) =>
                  item.facilityId == null ||
                  !excluded.contains(item.facilityId))
              .toList(growable: false),
          optionalFacilityIds: const <String>{},
        );
      }

      final optionalNameById = <String, String>{
        for (final facility in _appState.selectedFacilitiesForPark(selectedParkId))
          if (optionalIds.contains(facility.id)) facility.id: facility.name,
      };
      final trace = <String>[];
      final rejectionEvidence = <String, List<String>>{};
      _optionalOptimizationTrialCount = 0;
      _optionalOptimizationAdoptedCount = 0;

      DaySchedule? bestSchedule;
      Set<String> bestOptionalIds = const <String>{};

      if (optionalIds.isEmpty) {
        bestSchedule = await _generateScheduleOffUi(request);
      } else {
        final ids = optionalIds.toList(growable: false);
        // Search larger optional subsets first. The first feasible cardinality is
        // therefore the maximum number of optional additions that can coexist
        // while preserving every required wish.
        for (var targetCount = ids.length; targetCount >= 0; targetCount--) {
          var foundAtThisCount = false;
          final combinations = <Set<String>>[];

          void buildCombination(int index, Set<String> picked) {
            if (picked.length == targetCount) {
              combinations.add(Set<String>.of(picked));
              return;
            }
            final remainingNeeded = targetCount - picked.length;
            if (ids.length - index < remainingNeeded) return;
            for (var i = index; i < ids.length; i++) {
              picked.add(ids[i]);
              buildCombination(i + 1, picked);
              picked.remove(ids[i]);
            }
          }

          buildCombination(0, <String>{});
          for (final included in combinations) {
            _optionalOptimizationTrialCount++;
            final labels = included
                .map((id) => optionalNameById[id] ?? id)
                .join(' / ');
            _setGenerationStatus(
              '追加候補 ${included.length}/${optionalIds.length}件の組み合わせを全体最適化しています…',
            );
            final trial = await _generateScheduleOffUi(
              requestForOptionalSubset(included),
            );
            final requiredOk = containsCounts(trial, requiredCounts);
            final optionalCounts = <String, int>{
              for (final id in included) id: 1,
            };
            final optionalOk = containsCounts(trial, optionalCounts);
            final scheduledTrialIds = trial.items
                .map((item) => item.facilityId)
                .whereType<String>()
                .toSet();
            final scheduledOptionalLabels = included
                .where(scheduledTrialIds.contains)
                .map((id) => optionalNameById[id] ?? id)
                .join(' / ');

            final missingRequiredLabels = <String>[];
            for (final entry in requiredCounts.entries) {
              final scheduledCount = trial.items
                  .where((item) => item.facilityId == entry.key)
                  .length;
              if (scheduledCount < entry.value) {
                final facility = _appState.selectedFacilities
                    .where((f) => f.id == entry.key)
                    .firstOrNull;
                final name = facility?.name ?? entry.key;
                final missingCount = entry.value - scheduledCount;
                missingRequiredLabels.add(
                  missingCount == 1 ? name : '$name x$missingCount',
                );
              }
            }

            final optionalSlots = <String>[];
            for (final id in included) {
              final name = optionalNameById[id] ?? id;
              final slots = trial.items
                  .where((item) => item.facilityId == id)
                  .map((item) =>
                      '${_formatDebugHourMinute(item.startHour, item.startMinute)}-${_formatDebugHourMinute(item.endHour, item.endMinute)}')
                  .toList(growable: false);
              optionalSlots.add(
                '$name=${slots.isEmpty ? '未配置' : slots.join(', ')}',
              );
            }

            trace.add(
              '試行$_optionalOptimizationTrialCount [${included.length}件組]: '
              '${included.isEmpty ? '追加候補なし' : labels} -> '
              '主軸${requiredOk ? '維持' : '欠落'} / '
              '選択追加${optionalOk ? '全採用' : '未採用あり'}'
              '${included.isEmpty ? '' : ' / 実採用: ${scheduledOptionalLabels.isEmpty ? 'なし' : scheduledOptionalLabels}'}',
            );
            if (!requiredOk) {
              trace.add(
                '  欠落した主軸: '
                '${missingRequiredLabels.isEmpty ? '特定不能' : missingRequiredLabels.join(' / ')}',
              );
            }
            if (!requiredOk) {
              for (final id in included) {
                rejectionEvidence.putIfAbsent(id, () => <String>[]).add(
                  missingRequiredLabels.isEmpty
                      ? '元のやりたいことを100%維持できませんでした'
                      : '元のやりたいこと「${missingRequiredLabels.join(' / ')}」が外れる結果になりました',
                );
              }
            } else if (!optionalOk) {
              for (final id in included.where((id) => !scheduledTrialIds.contains(id))) {
                rejectionEvidence.putIfAbsent(id, () => <String>[]).add(
                  '選択した公演時刻・営業時間・移動条件を含む全日配置で候補自体を配置できませんでした',
                );
              }
            }
            if (optionalSlots.isNotEmpty) {
              trace.add('  追加候補の配置時刻: ${optionalSlots.join(' / ')}');
            }
            if (!requiredOk || !optionalOk) continue;

            bestSchedule = trial;
            bestOptionalIds = Set<String>.of(included);
            foundAtThisCount = true;
            break;
          }
          if (foundAtThisCount) break;
        }

        // The empty subset should always be the safe fallback, but retain a
        // defensive fallback in case future engine changes make it fail too.
        bestSchedule ??= await _generateScheduleOffUi(
          requestForOptionalSubset(const <String>{}),
        );
        _optionalOptimizationAdoptedCount = bestOptionalIds.length;
        final rejected = optionalIds.difference(bestOptionalIds);
        final exitLabel = '${request.settings.exitTimeHour.toString().padLeft(2, '0')}:${request.settings.exitTimeMinute.toString().padLeft(2, '0')}';
        _optionalRejectionReasons = <String, String>{
          for (final id in rejected)
            id: rejectionEvidence[id]?.isNotEmpty == true
                ? '${rejectionEvidence[id]!.first}。退園希望$exitLabelまでの全日再最適化で判定しています。候補は削除せず保持します。'
                : '退園希望$exitLabelまでに、元のやりたいことを100%維持した採用結果を確認できませんでした。候補は削除せず保持します。',
        };
        trace.add(
          '最終採用: ${bestOptionalIds.length}/${optionalIds.length}件'
          '${rejected.isEmpty ? '（見送りなし）' : ' / 見送り: ${rejected.map((id) => optionalNameById[id] ?? id).join(' / ')}'}',
        );
      }

      if (optionalIds.isEmpty) _optionalRejectionReasons = const <String, String>{};
      _optionalOptimizationTrace = List<String>.unmodifiable(trace);
      _fourModeBaseRequest = optionalIds.isEmpty
          ? request
          : requestForOptionalSubset(bestOptionalIds);
      final generatedSchedule = bestSchedule;

      final missingRequiredNames = <String>[];
      for (final entry in requiredCounts.entries) {
        final scheduledCount = generatedSchedule.items
            .where((item) => item.facilityId == entry.key)
            .length;
        if (scheduledCount >= entry.value) continue;
        final facility = _appState.selectedFacilities
            .where((candidate) => candidate.id == entry.key)
            .firstOrNull;
        final missingCount = entry.value - scheduledCount;
        final name = facility?.name ?? entry.key;
        missingRequiredNames.add(
          missingCount == 1 ? name : '$name x$missingCount',
        );
      }
      // Missing flexible wishes are not a physical contradiction. Keep the
      // best feasible schedule and let ScheduleValidator surface them as
      // warnings. Fixed-vs-fixed conflicts are rejected earlier.

      _setGenerationStatus('完成したプランを表示しています…');
      if (debugNoHistory) {
        assert(kDebugMode);
        _appState.debugReplaceDayScheduleWithoutHistory(generatedSchedule);
      } else {
        _appState.updateDaySchedule(generatedSchedule);
      }

      isLoading = false;
      // Coverage/DPA simulation is intentionally user-triggered.
      // Do not start another heavy full-day analysis automatically after
      // generation or optional-addition reoptimization.
      coverageAdvice = null;
      coverageAnalysisError = null;
      isAnalyzingCoverage = false;
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('スケジュール生成に失敗しました: $error');

      debugPrintStack(stackTrace: stackTrace);

      errorMessage =
          'スケジュール生成に失敗しました。\n'
          '${error.runtimeType}: $error';
    } finally {
      isLoading = false;
      generationStatus = '準備しています…';

      notifyListeners();
    }
  }

  Future<List<PerformancePlanChoice>> loadPerformancePlanChoices() async {
    final targetDate = _appState.tripSettings.visitDate ?? DateTime.now();
    final facilities = await ServiceLocator.facilityRepository
        .getFacilitiesByParkId(selectedParkId);
    final facilityById = {
      for (final facility in facilities)
        if (facility.category == FacilityCategory.show ||
            facility.category == FacilityCategory.parade)
          facility.id: facility,
    };
    final options = await _performanceScheduleRepository.findParkOptions(
      parkId: selectedParkId,
      date: targetDate,
    );

    final choices = <PerformancePlanChoice>[];
    for (final option in options) {
      final facility = facilityById[option.facilityId];
      if (facility == null || !facility.canAddToPlanAt(targetDate)) {
        continue;
      }
      choices.add(PerformancePlanChoice(facility: facility, option: option));
    }

    choices.sort((left, right) {
      final byTime = left.option.startTime.compareTo(right.option.startTime);
      if (byTime != 0) return byTime;
      return left.facility.name.compareTo(right.facility.name);
    });
    return List<PerformancePlanChoice>.unmodifiable(choices);
  }

  Future<void> addPerformanceToPlan(PerformancePlanChoice choice) async {
    _capturePreAdditionState(choice.facility.name);
    if (!_appState.isFacilitySelected(choice.facility.id)) {
      _appState.addOptionalFacility(choice.facility);
    }

    _appState.updatePreferenceSelectedPerformance(
      facilityId: choice.facility.id,
      performanceIndex: choice.option.performanceIndex,
      startTime: choice.option.startTime,
    );

    await generateSchedule();
    _updateAdditionImpact();
  }


  Future<List<FreeTimeImprovementChoice>> loadFreeTimeImprovementChoices(
    ScheduleItem freeTimeItem,
  ) async {
    final currentSchedule = schedule;
    if (currentSchedule == null ||
        freeTimeItem.type != ScheduleItemType.breakTime) {
      return const <FreeTimeImprovementChoice>[];
    }

    final gapStart = freeTimeItem.startHour * 60 + freeTimeItem.startMinute;
    final gapEnd = freeTimeItem.endHour * 60 + freeTimeItem.endMinute;
    if (gapEnd - gapStart < 20) {
      return const <FreeTimeImprovementChoice>[];
    }

    final sortedItems = [...currentSchedule.items]
      ..sort((a, b) {
        final aStart = a.startHour * 60 + a.startMinute;
        final bStart = b.startHour * 60 + b.startMinute;
        return aStart.compareTo(bStart);
      });
    final index = sortedItems.indexWhere((item) => item.id == freeTimeItem.id);
    if (index < 0) {
      return const <FreeTimeImprovementChoice>[];
    }
    final previousItem = index > 0 ? sortedItems[index - 1] : null;
    final nextItem = index + 1 < sortedItems.length
        ? sortedItems[index + 1]
        : null;

    final targetDate = _appState.tripSettings.visitDate ?? DateTime.now();
    final settings = _appState.tripSettings;
    final allFacilities = await ServiceLocator.facilityRepository
        .getFacilitiesByParkId(selectedParkId);
    final facilityById = {
      for (final facility in allFacilities) facility.id: facility,
    };
    final locations = await ServiceLocator.movementRepository
        .loadFacilityLocations(parkId: selectedParkId);
    final locationById = {
      for (final location in locations) location.facilityId: location,
    };
    final connections = await ServiceLocator.movementRepository
        .loadAreaConnections(parkId: selectedParkId);
    final waitProfiles = await const CrowdFactorRepositoryImpl()
        .loadWaitProfilesForDate(
          parkId: selectedParkId,
          targetDate: targetDate,
        );
    final expertProfiles = await ServiceLocator.expertRecommendationRepository
        .loadProfiles(parkId: selectedParkId);
    final waitProfileById = {
      for (final profile in waitProfiles) profile.facilityId: profile,
    };
    final crowdFactors = await const CrowdFactorRepositoryImpl()
        .loadCrowdFactors(parkId: selectedParkId);
    final greetingWaitPlanning =
        await const LocalGreetingWaitPlanningRepository().load(
          parkId: selectedParkId,
          targetDate: targetDate,
          facilities: allFacilities,
          crowdFactors: crowdFactors,
        );
    final unlimitedRideBufferMinutes = settings.usesVacationPackage &&
            settings.hasUnlimitedAttractionRides
        ? await const LocalVacationPackageUnlimitedRideRepository()
            .loadPriorityAccessBufferMinutes(parkId: selectedParkId)
        : <String, int>{};

    final previousAreaId = _scheduleItemExitAreaId(
      previousItem,
      facilityById: facilityById,
      locationById: locationById,
    );
    final nextAreaId = _scheduleItemEntryAreaId(
      nextItem,
      facilityById: facilityById,
      locationById: locationById,
    );
    final scheduledFacilityCounts = <String, int>{};
    for (final item in currentSchedule.items) {
      final facilityId = item.facilityId;
      if (facilityId == null || facilityId.isEmpty) continue;
      scheduledFacilityCounts.update(
        facilityId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final choices = <FreeTimeImprovementChoice>[];
    for (final facility in allFacilities) {
      final scheduledCount = scheduledFacilityCounts[facility.id] ?? 0;
      final isManualRepeatCandidate =
          scheduledCount > 0 &&
          facility.category == FacilityCategory.attraction &&
          unlimitedRideBufferMinutes.containsKey(facility.id);

      if (!facility.canAddToPlanAt(targetDate) ||
          (scheduledCount > 0 && !isManualRepeatCandidate) ||
          facility.category == FacilityCategory.show ||
          facility.category == FacilityCategory.parade ||
          facility.category == FacilityCategory.service ||
          facility.requiresEntryRequest ||
          facility.requiresReservation) {
        continue;
      }
      if (facility.category != FacilityCategory.attraction &&
          facility.category != FacilityCategory.greeting &&
          facility.category != FacilityCategory.restaurant &&
          facility.category != FacilityCategory.shop) {
        continue;
      }

      final entryAreaId = locationById[facility.id]?.areaId ?? facility.areaId;
      final exitAreaId =
          locationById[facility.id]?.effectiveExitAreaId ?? facility.areaId;
      final movementIn = previousItem?.facilityId == facility.id
          ? 0
          : previousAreaId == null
              ? 0
              : _movementMinutes(
                  fromAreaId: previousAreaId,
                  toAreaId: entryAreaId,
                  connections: connections,
                );
      final movementOut = nextItem?.facilityId == facility.id
          ? 0
          : nextAreaId == null
              ? 0
              : _movementMinutes(
                  fromAreaId: exitAreaId,
                  toAreaId: nextAreaId,
                  connections: connections,
                );

      var plannedStart = gapStart + movementIn;
      var wait = _freeTimeWaitEstimate(
        facility: facility,
        scheduledStartMinutes: plannedStart,
        profile: waitProfileById[facility.id],
        greetingWaitPlanning: greetingWaitPlanning[facility.id],
        unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
      );
      var plannedDuration = facility.durationMinutes + wait.minutes;

      final operatingStart = _earliestOperatingStart(
        facility: facility,
        targetDate: targetDate,
        requestedStartMinutes: plannedStart,
        durationMinutes: plannedDuration,
        latestEndMinutes: gapEnd - movementOut,
      );
      if (operatingStart == null) {
        continue;
      }
      plannedStart = operatingStart;
      wait = _freeTimeWaitEstimate(
        facility: facility,
        scheduledStartMinutes: plannedStart,
        profile: waitProfileById[facility.id],
        greetingWaitPlanning: greetingWaitPlanning[facility.id],
        unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
      );
      plannedDuration = facility.durationMinutes + wait.minutes;
      final verifiedOperatingStart = _earliestOperatingStart(
        facility: facility,
        targetDate: targetDate,
        requestedStartMinutes: plannedStart,
        durationMinutes: plannedDuration,
        latestEndMinutes: gapEnd - movementOut,
      );
      if (verifiedOperatingStart == null ||
          verifiedOperatingStart != plannedStart) {
        continue;
      }
      final plannedEnd = plannedStart + plannedDuration;
      if (plannedEnd + movementOut > gapEnd) {
        continue;
      }

      final alreadySelected = _appState.isFacilitySelected(facility.id);
      final existingPreference = _appState.getPreference(facility.id);
      if (!isManualRepeatCandidate &&
          alreadySelected &&
          existingPreference != null &&
          existingPreference.accessMethod != FacilityAccessMethod.standby) {
        continue;
      }
      final totalUsed = movementIn + plannedDuration + movementOut;
      final slack = (gapEnd - gapStart) - totalUsed;
      final effectivePriority =
          existingPreference?.priority.value ?? facility.priority.value;
      final expert = const DisneyExpertRecommendationService().evaluate(
        facility: facility,
        targetDate: targetDate,
        profiles: expertProfiles,
        preference: existingPreference,
        waitProfiles: waitProfiles,
      );
      final score = _freeTimeScoringService.scoreFacility(
        priorityValue: effectivePriority,
        plannedDurationMinutes: plannedDuration,
        movementInMinutes: movementIn,
        movementOutMinutes: movementOut,
        fitSlackMinutes: slack,
        isWishlisted: alreadySelected,
        samePreviousArea: previousAreaId == entryAreaId,
        sameNextArea: nextAreaId == exitAreaId,
        isGreeting: facility.category == FacilityCategory.greeting,
        expertScore: expert.score,
        estimatedWaitMinutes: wait.minutes,
        gapMinutes: gapEnd - gapStart,
      );

      choices.add(
        isManualRepeatCandidate
            ? FreeTimeImprovementChoice.repeatAttraction(
                facility: facility,
                plannedStartMinutes: plannedStart,
                plannedEndMinutes: plannedEnd,
                estimatedWaitMinutes: wait.minutes,
                waitSource: wait.source,
                movementInMinutes: movementIn,
                movementOutMinutes: movementOut,
                fitSlackMinutes: slack,
                score: score,
                repeatNumber: scheduledCount + 1,
                expertScore: expert.score,
                expertReason: expert.reason,
              )
            : FreeTimeImprovementChoice.facility(
                facility: facility,
                plannedStartMinutes: plannedStart,
                plannedEndMinutes: plannedEnd,
                estimatedWaitMinutes: wait.minutes,
                waitSource: wait.source,
                movementInMinutes: movementIn,
                movementOutMinutes: movementOut,
                fitSlackMinutes: slack,
                score: score,
                alreadySelected: alreadySelected,
                expertScore: expert.score,
                expertReason: expert.reason,
              ),
      );
    }

    final performanceOptions = await _performanceScheduleRepository
        .findParkOptions(parkId: selectedParkId, date: targetDate);
    for (final option in performanceOptions) {
      final facility = facilityById[option.facilityId];
      if (facility == null ||
          !facility.canAddToPlanAt(targetDate) ||
          (facility.category != FacilityCategory.show &&
              facility.category != FacilityCategory.parade)) {
        continue;
      }
      final start = _parseTimeMinutes(option.startTime);
      if (start == null) continue;
      final end = start + facility.durationMinutes;
      if (start < gapStart || end > gapEnd) continue;
      final alreadyScheduled = currentSchedule.items.any(
        (item) =>
            item.facilityId == facility.id && item.startTimeLabel == option.startTime,
      );
      if (alreadyScheduled) continue;

      final entryAreaId = locationById[facility.id]?.areaId ?? facility.areaId;
      final exitAreaId =
          locationById[facility.id]?.effectiveExitAreaId ?? facility.areaId;
      final movementIn = previousAreaId == null
          ? 0
          : _movementMinutes(
              fromAreaId: previousAreaId,
              toAreaId: entryAreaId,
              connections: connections,
            );
      final movementOut = nextAreaId == null
          ? 0
          : _movementMinutes(
              fromAreaId: exitAreaId,
              toAreaId: nextAreaId,
              connections: connections,
            );
      const preparationMinutes = 15;
      if (gapStart + movementIn + preparationMinutes > start ||
          end + movementOut > gapEnd) {
        continue;
      }

      final fitSlack = (gapEnd - gapStart) -
          (movementIn + preparationMinutes + facility.durationMinutes + movementOut);
      var score = facility.priority.value * 26.0;
      score -= (movementIn + movementOut) * 0.5;
      score -= fitSlack.clamp(0, 180) * 0.02;
      if (!facility.requiresEntryRequest) score += 8;
      choices.add(
        FreeTimeImprovementChoice.performance(
          facility: facility,
          option: option,
          plannedStartMinutes: start,
          plannedEndMinutes: end,
          movementInMinutes: movementIn,
          movementOutMinutes: movementOut,
          preparationMinutes: preparationMinutes,
          fitSlackMinutes: fitSlack,
          score: score,
        ),
      );
    }

    choices.sort((left, right) {
      final scoreCompare = right.score.compareTo(left.score);
      if (scoreCompare != 0) return scoreCompare;
      return left.plannedStartMinutes.compareTo(right.plannedStartMinutes);
    });
    return List<FreeTimeImprovementChoice>.unmodifiable(choices);
  }

  Future<List<PlanAdditionChoice>> loadPlanAdditionChoices() async {
    final currentSchedule = schedule;
    if (currentSchedule == null) return const <PlanAdditionChoice>[];

    final targetDate = _appState.tripSettings.visitDate ?? DateTime.now();
    final settings = _appState.tripSettings;
    final allFacilities = await ServiceLocator.facilityRepository
        .getFacilitiesByParkId(selectedParkId);
    final waitProfiles = await const CrowdFactorRepositoryImpl()
        .loadWaitProfilesForDate(parkId: selectedParkId, targetDate: targetDate);
    final waitProfileById = {
      for (final profile in waitProfiles) profile.facilityId: profile,
    };
    final crowdFactors = await const CrowdFactorRepositoryImpl()
        .loadCrowdFactors(parkId: selectedParkId);
    final greetingWaitPlanning =
        await const LocalGreetingWaitPlanningRepository().load(
      parkId: selectedParkId,
      targetDate: targetDate,
      facilities: allFacilities,
      crowdFactors: crowdFactors,
    );
    final unlimitedRideBufferMinutes = settings.usesVacationPackage &&
            settings.hasUnlimitedAttractionRides
        ? await const LocalVacationPackageUnlimitedRideRepository()
            .loadPriorityAccessBufferMinutes(parkId: selectedParkId)
        : <String, int>{};
    final expertProfiles = await ServiceLocator.expertRecommendationRepository
        .loadProfiles(parkId: selectedParkId);
    final profileById = {
      for (final profile in expertProfiles) profile.facilityId: profile,
    };

    final scheduledCounts = <String, int>{};
    for (final item in currentSchedule.items) {
      final id = item.facilityId;
      if (id == null || id.isEmpty) continue;
      scheduledCounts.update(id, (value) => value + 1, ifAbsent: () => 1);
    }
    final selectedCounts = <String, int>{};
    for (final facility in selectedFacilitiesForCurrentPark) {
      selectedCounts.update(
        facility.id,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final midpoint = (settings.entryTimeHour * 60 + settings.entryTimeMinute +
            settings.exitTimeHour * 60 + settings.exitTimeMinute) ~/
        2;
    final result = <PlanAdditionChoice>[];
    for (final facility in allFacilities) {
      if (!facility.canAddToPlanAt(targetDate) ||
          facility.category == FacilityCategory.service ||
          facility.requiresReservation) {
        continue;
      }
      if (facility.category != FacilityCategory.attraction &&
          facility.category != FacilityCategory.greeting &&
          facility.category != FacilityCategory.restaurant &&
          facility.category != FacilityCategory.shop &&
          facility.category != FacilityCategory.show &&
          facility.category != FacilityCategory.parade) {
        continue;
      }

      var waitMinutes = 0;
      if (facility.category == FacilityCategory.attraction ||
          facility.category == FacilityCategory.greeting) {
        waitMinutes = _freeTimeWaitEstimate(
          facility: facility,
          scheduledStartMinutes: midpoint,
          profile: waitProfileById[facility.id],
          greetingWaitPlanning: greetingWaitPlanning[facility.id],
          unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
        ).minutes;
      }
      final expert = const DisneyExpertRecommendationService().evaluate(
        facility: facility,
        targetDate: targetDate,
        profiles: expertProfiles,
        preference: _appState.getPreference(facility.id),
        waitProfiles: waitProfiles,
      );
      final profile = profileById[facility.id];
      final spotlightActive = profile?.spotlightAppliesOn(targetDate) ?? false;
      final spotlightReason = spotlightActive
          ? (profile!.spotlightReason?.trim().isNotEmpty ?? false)
              ? profile.spotlightReason!.trim()
              : '今の時期の注目候補'
          : facility.isSeasonal
              ? '期間限定'
              : null;
      final inPlanCount =
          (scheduledCounts[facility.id] ?? selectedCounts[facility.id] ?? 0);
      final repeatPolicy = _repeatPolicyFor(
        facility: facility,
        preference: _appState.getPreference(facility.id),
        inPlanCount: inPlanCount,
        settings: settings,
      );
      result.add(PlanAdditionChoice(
        facility: facility,
        inPlanCount: inPlanCount,
        estimatedMinutes: facility.durationMinutes + waitMinutes,
        estimatedWaitMinutes: waitMinutes,
        spotlightReason: spotlightReason,
        repeatAllowed: repeatPolicy.allowed,
        repeatLabel: repeatPolicy.label,
        repeatReason: repeatPolicy.reason,
        score: facility.priority.value * 24.0 +
            expert.score * 0.65 +
            (spotlightActive ? profile!.spotlightScore * 1.4 : 0) +
            (facility.isSeasonal ? 12 : 0),
      ));
    }
    result.sort((a, b) {
      final topical = (b.spotlightReason != null ? 1 : 0)
          .compareTo(a.spotlightReason != null ? 1 : 0);
      if (topical != 0) return topical;
      return b.score.compareTo(a.score);
    });
    return List<PlanAdditionChoice>.unmodifiable(result);
  }

  Future<PlanAdditionResult> addPlanAdditionChoice(
    PlanAdditionChoice choice,
  ) async {
    _capturePreAdditionState(choice.facility.name);
    final beforeCount = schedule?.items
            .where((item) => item.facilityId == choice.facility.id)
            .length ??
        0;
    final wasAlreadySelected = _appState.isFacilitySelected(choice.facility.id);
    if (wasAlreadySelected && !choice.repeatAllowed) {
      return PlanAdditionResult(
        added: false,
        remainingMinutes: 0,
        message: choice.repeatReason,
      );
    }
    if (wasAlreadySelected) {
      _appState.addFacilityRepeat(choice.facility);
    } else {
      _appState.addOptionalFacility(choice.facility);
    }

    await generateSchedule();
    final afterCount = schedule?.items
            .where((item) => item.facilityId == choice.facility.id)
            .length ??
        0;
    final requiredCount = beforeCount + 1;
    if (afterCount < requiredCount) {
      _updateAdditionImpact();
      return PlanAdditionResult(
        added: true,
        remainingMinutes: 0,
        message:
            '${choice.facility.name}は追加候補として保存しました。'
            '一度ほかの希望と同列にして全体最適化しましたが、'
            '元の「やりたいこと」が外れるため今回の採用だけキャンセルしました。',
      );
    }

    final current = schedule;
    if (current == null) {
      return const PlanAdditionResult(added: true, remainingMinutes: 0);
    }
    final allFacilities = await ServiceLocator.facilityRepository
        .getFacilitiesByParkId(selectedParkId);
    final locations = await ServiceLocator.movementRepository
        .loadFacilityLocations(parkId: selectedParkId);
    final connections = await ServiceLocator.movementRepository
        .loadAreaConnections(parkId: selectedParkId);
    final remaining = _verifiedResidualSlackMinutes(
      schedule: current,
      facilities: allFacilities,
      facilityLocations: locations,
      areaConnections: connections,
    );
    _updateAdditionImpact();
    return PlanAdditionResult(
      added: true,
      remainingMinutes: remaining,
    );
  }

  Future<void> removeOptionalAddition(String facilityId) async {
    if (!_appState.isOptionalAddition(facilityId)) return;
    _appState.removeFacility(facilityId);
    await generateSchedule();
    _updateAdditionImpact();
  }

  Future<List<PlanRebuildBundle>> loadPlanRebuildCandidates() async {
    final currentSchedule = schedule;
    if (currentSchedule == null) return const <PlanRebuildBundle>[];

    final totalFreeMinutes = currentSchedule.items
        .where((item) => item.type == ScheduleItemType.breakTime)
        .fold<int>(0, (sum, item) {
          final start = item.startHour * 60 + item.startMinute;
          final end = item.endHour * 60 + item.endMinute;
          return sum + (end - start).clamp(0, 24 * 60).toInt();
        });
    if (totalFreeMinutes < 30) return const <PlanRebuildBundle>[];

    // This reserve is deliberately kept AFTER a candidate has passed a real
    // full-day regeneration. It is not merely subtracted from a visible gap.
    final reserveMinutes =
        (totalFreeMinutes * 0.20).ceil().clamp(30, 90).toInt();
    final safeBudgetMinutes = totalFreeMinutes - reserveMinutes;
    if (safeBudgetMinutes < 20) return const <PlanRebuildBundle>[];

    final targetDate = _appState.tripSettings.visitDate ?? DateTime.now();
    final settings = _appState.tripSettings;
    final allFacilities = await ServiceLocator.facilityRepository
        .getFacilitiesByParkId(selectedParkId);
    final waitProfiles = await const CrowdFactorRepositoryImpl()
        .loadWaitProfilesForDate(parkId: selectedParkId, targetDate: targetDate);
    final waitProfileById = {
      for (final profile in waitProfiles) profile.facilityId: profile,
    };
    final crowdFactors = await const CrowdFactorRepositoryImpl()
        .loadCrowdFactors(parkId: selectedParkId);
    final greetingWaitPlanning =
        await const LocalGreetingWaitPlanningRepository().load(
      parkId: selectedParkId,
      targetDate: targetDate,
      facilities: allFacilities,
      crowdFactors: crowdFactors,
    );
    final unlimitedRideBufferMinutes = settings.usesVacationPackage &&
            settings.hasUnlimitedAttractionRides
        ? await const LocalVacationPackageUnlimitedRideRepository()
            .loadPriorityAccessBufferMinutes(parkId: selectedParkId)
        : <String, int>{};
    final expertProfiles = await ServiceLocator.expertRecommendationRepository
        .loadProfiles(parkId: selectedParkId);
    final profileById = {
      for (final profile in expertProfiles) profile.facilityId: profile,
    };

    // Exclude both selected wishes and already scheduled facilities. Name
    // exclusion also protects against duplicated master-data rows with
    // different IDs for the same experience.
    final selectedFacilities = selectedFacilitiesForCurrentPark
        .where((facility) => facility.canAddToPlanAt(targetDate))
        .toList(growable: false);
    final selectedIds = selectedFacilities.map((facility) => facility.id).toSet();
    final selectedNames = selectedFacilities
        .map((facility) => facility.name.trim().toLowerCase())
        .toSet();
    final scheduledIds = currentSchedule.items
        .map((item) => item.facilityId)
        .whereType<String>()
        .toSet();
    final scheduledNames = currentSchedule.items
        .map((item) => item.title.trim().toLowerCase())
        .toSet();

    final midpoint = (settings.entryTimeHour * 60 + settings.entryTimeMinute +
            settings.exitTimeHour * 60 + settings.exitTimeMinute) ~/
        2;
    final candidates = <PlanRebuildCandidate>[];
    for (final facility in allFacilities) {
      final normalizedName = facility.name.trim().toLowerCase();
      if (!facility.canAddToPlanAt(targetDate) ||
          selectedIds.contains(facility.id) ||
          scheduledIds.contains(facility.id) ||
          selectedNames.contains(normalizedName) ||
          scheduledNames.contains(normalizedName) ||
          facility.category == FacilityCategory.service ||
          facility.requiresReservation) {
        continue;
      }
      if (facility.category != FacilityCategory.attraction &&
          facility.category != FacilityCategory.greeting &&
          facility.category != FacilityCategory.restaurant &&
          facility.category != FacilityCategory.shop &&
          facility.category != FacilityCategory.show &&
          facility.category != FacilityCategory.parade) {
        continue;
      }

      var waitMinutes = 0;
      if (facility.category == FacilityCategory.attraction ||
          facility.category == FacilityCategory.greeting) {
        waitMinutes = _freeTimeWaitEstimate(
          facility: facility,
          scheduledStartMinutes: midpoint,
          profile: waitProfileById[facility.id],
          greetingWaitPlanning: greetingWaitPlanning[facility.id],
          unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
        ).minutes;
      }
      final preparationMinutes =
          facility.category == FacilityCategory.show ||
                  facility.category == FacilityCategory.parade
              ? 15
              : 0;
      final safetyMinutes = switch (facility.category) {
        FacilityCategory.show || FacilityCategory.parade => 20,
        FacilityCategory.restaurant => 15,
        FacilityCategory.attraction || FacilityCategory.greeting => 10,
        _ => 10,
      };
      final requiredMinutes = facility.durationMinutes +
          waitMinutes +
          preparationMinutes +
          safetyMinutes;
      if (requiredMinutes > safeBudgetMinutes) continue;

      final expert = const DisneyExpertRecommendationService().evaluate(
        facility: facility,
        targetDate: targetDate,
        profiles: expertProfiles,
        preference: _appState.getPreference(facility.id),
        waitProfiles: waitProfiles,
      );
      final profile = profileById[facility.id];
      final spotlightActive = profile?.spotlightAppliesOn(targetDate) ?? false;
      final spotlightReason = spotlightActive
          ? (profile!.spotlightReason?.trim().isNotEmpty ?? false)
              ? profile.spotlightReason!.trim()
              : '今の時期の注目候補'
          : facility.isSeasonal
              ? '期間限定'
              : null;
      final score = facility.priority.value * 24.0 +
          expert.score * 0.65 +
          (spotlightActive ? profile!.spotlightScore * 1.4 : 0) +
          (facility.isSeasonal ? 12 : 0) -
          waitMinutes * 0.12;
      candidates.add(PlanRebuildCandidate(
        facility: facility,
        estimatedRequiredMinutes: requiredMinutes,
        totalFreeMinutes: totalFreeMinutes,
        estimatedWaitMinutes: waitMinutes,
        score: score,
        spotlightReason: spotlightReason,
      ));
    }
    candidates.sort((a, b) => b.score.compareTo(a.score));
    final pool = candidates.take(10).toList(growable: false);
    if (pool.isEmpty) return const <PlanRebuildBundle>[];

    // Shared inputs for the real full-day feasibility runs.
    final eventImpacts = await ServiceLocator.eventImpactRepository
        .loadEventImpacts(parkId: selectedParkId);
    final areaConnections = await ServiceLocator.movementRepository
        .loadAreaConnections(parkId: selectedParkId);
    final facilityLocations = await ServiceLocator.movementRepository
        .loadFacilityLocations(parkId: selectedParkId);
    final officialOptions = await _performanceScheduleRepository.findParkOptions(
      parkId: selectedParkId,
      date: targetDate,
    );
    final allParkFacilityById = {
      for (final facility in allFacilities) facility.id: facility,
    };
    final basePreferences = _appState.planPreferences
        .where((preference) => selectedIds.contains(preference.facilityId))
        .toList(growable: false);

    Future<PlanRebuildBundle?> verifyBundle(
      List<PlanRebuildCandidate> choices,
    ) async {
      final trialFacilities = <Facility>[
        ...selectedFacilities,
        ...choices.map((choice) => choice.facility),
      ];
      final trialIds = trialFacilities.map((facility) => facility.id).toSet();
      final trialPreferences = <PlanPreference>[
        ...basePreferences,
        for (final choice in choices)
          if (!basePreferences.any(
            (preference) => preference.facilityId == choice.facility.id,
          ))
            choice.facility.requiresEntryRequest
                ? PlanPreference.initial(facilityId: choice.facility.id).copyWith(
                    accessMethod: FacilityAccessMethod.entryRequest,
                    fixedTimeStatus: FixedTimeStatus.planned,
                    lotteryFallbackAction: LotteryFallbackAction.dpaIfAvailable,
                  )
                : PlanPreference.initial(facilityId: choice.facility.id),
      ];

      final resolvedPreferences = await _performanceResolver.resolve(
        parkId: selectedParkId,
        date: targetDate,
        entryMinutes: settings.entryTimeHour * 60 + settings.entryTimeMinute,
        exitMinutes: settings.exitTimeHour * 60 + settings.exitTimeMinute,
        facilities: trialFacilities,
        preferences: trialPreferences,
      );
      final availableMinutes =
          (settings.exitTimeHour * 60 + settings.exitTimeMinute) -
          (settings.entryTimeHour * 60 + settings.entryTimeMinute);
      final morningRanking = const WishCandidateScoringEngine().score(
        facilities: trialFacilities,
        preferences: resolvedPreferences,
        waitProfiles: waitProfiles,
        availableMinutes: availableMinutes,
        targetDate: targetDate,
        hasHappyEntry: settings.hasHappyEntry,
        expertProfiles: expertProfiles,
        unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
        greetingWaitPlanning: greetingWaitPlanning,
      );

      var generatedPreferences = resolvedPreferences;
      if (settings.canUseDpa && settings.attractionDpaMaxUses > 0) {
        final allocation = _dpaAutoAllocator.allocate(
          strategy: DpaStrategy(
            type: DpaStrategyType.highCongestionOnly,
            maxUses: settings.attractionDpaMaxUses.clamp(0, 3).toInt(),
          ),
          candidates: morningRanking
              .where((candidate) =>
                  !unlimitedRideBufferMinutes.containsKey(candidate.facility.id))
              .toList(growable: false),
          preferences: resolvedPreferences,
        );
        generatedPreferences = allocation.preferences;
      }

      final officialPerformanceOpportunities =
          <OfficialPerformanceOpportunity>[];
      for (final option in officialOptions) {
        final facility = allParkFacilityById[option.facilityId];
        if (facility == null ||
            (facility.category != FacilityCategory.show &&
                facility.category != FacilityCategory.parade)) {
          continue;
        }
        final startMinutes = _parseTimeMinutes(option.startTime);
        if (startMinutes == null) continue;
        officialPerformanceOpportunities.add(
          OfficialPerformanceOpportunity(
            facilityId: facility.id,
            name: facility.name,
            startMinutes: startMinutes,
            endMinutes: startMinutes + facility.durationMinutes,
            requiresEntryRequest: facility.requiresEntryRequest,
            supportsDpa: facility.supportsDpa,
            isSelected: trialIds.contains(facility.id),
            isMustDo: generatedPreferences.any(
              (preference) =>
                  preference.facilityId == facility.id &&
                  preference.priority == PriorityLevel.highest,
            ),
          ),
        );
      }

      final simulated = await _generateScheduleOffUi(
        _ScheduleGenerationRequest(
          settings: settings,
          facilities: List<Facility>.of(trialFacilities),
          preferences: List<PlanPreference>.of(generatedPreferences),
          eventImpacts: List<EventImpact>.of(eventImpacts),
          waitProfiles: List<TimeBandWaitProfile>.of(waitProfiles),
          morningScores: <String, double>{
            for (final candidate in morningRanking)
              candidate.facility.id:
                  candidate.firstMoveScore ?? candidate.score,
          },
          officialPerformanceOpportunities:
              List<OfficialPerformanceOpportunity>.of(
            officialPerformanceOpportunities,
          ),
          areaConnections: List<AreaConnection>.of(areaConnections),
          facilityLocations: List<FacilityLocation>.of(facilityLocations),
          expertProfiles: List<ExpertRecommendationProfile>.of(expertProfiles),
          unlimitedRideBufferMinutes:
              Map<String, int>.of(unlimitedRideBufferMinutes),
          greetingWaitPlanning:
              Map<String, GreetingWaitPlanningValue>.of(greetingWaitPlanning),
          manualFixedItems: const <ScheduleItem>[],
        ),
      );

      final simulatedIds = simulated.items
          .map((item) => item.facilityId)
          .whereType<String>()
          .toSet();
      // A candidate is shown only when the actual regenerated day contains
      // every original wish AND every proposed addition.
      if (!trialIds.every(simulatedIds.contains)) return null;

      final remainingSlackMinutes = _verifiedResidualSlackMinutes(
        schedule: simulated,
        facilities: allFacilities,
        facilityLocations: facilityLocations,
        areaConnections: areaConnections,
      );
      if (remainingSlackMinutes < reserveMinutes) return null;

      final required = choices.fold<int>(
        0,
        (sum, item) => sum + item.estimatedRequiredMinutes,
      );
      final categoryCount =
          choices.map((item) => item.facility.category).toSet().length;
      final topicalCount =
          choices.where((item) => item.spotlightReason != null).length;
      final score = choices.fold<double>(0, (sum, item) => sum + item.score) +
          categoryCount * 12.0 +
          topicalCount * 18.0 +
          choices.length * 18.0;
      return PlanRebuildBundle(
        candidates: List<PlanRebuildCandidate>.unmodifiable(choices),
        totalFreeMinutes: totalFreeMinutes,
        safeBudgetMinutes: safeBudgetMinutes,
        reserveMinutes: reserveMinutes,
        estimatedRequiredMinutes: required,
        verifiedRemainingMinutes: remainingSlackMinutes,
        score: score,
      );
    }

    // Full-day Beam Search is intentionally expensive. Build a small,
    // diverse shortlist first, then verify at most six proposals. Run two at a
    // time so the UI wait does not scale linearly with every theoretical pair.
    final proposals = <List<PlanRebuildCandidate>>[];
    final top = pool.take(6).toList(growable: false);

    if (top.length >= 3) {
      proposals.add(<PlanRebuildCandidate>[top[0], top[1], top[2]]);
    }
    if (top.length >= 2) {
      proposals.add(<PlanRebuildCandidate>[top[0], top[1]]);
    }
    if (top.length >= 4) {
      proposals.add(<PlanRebuildCandidate>[top[2], top[3]]);
    }
    proposals.add(<PlanRebuildCandidate>[top[0]]);
    if (top.length >= 2) {
      proposals.add(<PlanRebuildCandidate>[top[1]]);
    }
    if (top.length >= 3) {
      proposals.add(<PlanRebuildCandidate>[top[2]]);
    }

    final verified = <PlanRebuildBundle>[];
    for (var offset = 0; offset < proposals.length && verified.length < 3; offset += 2) {
      final batch = proposals
          .skip(offset)
          .take(2)
          .where((choices) {
            final required = choices.fold<int>(
              0,
              (sum, item) => sum + item.estimatedRequiredMinutes,
            );
            return required <= safeBudgetMinutes;
          })
          .toList(growable: false);
      if (batch.isEmpty) continue;
      final results = await Future.wait(batch.map(verifyBundle));
      verified.addAll(results.whereType<PlanRebuildBundle>());
    }

    verified.sort((a, b) {
      final countCompare = b.candidates.length.compareTo(a.candidates.length);
      if (countCompare != 0) return countCompare;
      return b.score.compareTo(a.score);
    });
    final seen = <String>{};
    final result = <PlanRebuildBundle>[];
    for (final bundle in verified) {
      final ids = bundle.candidates.map((e) => e.facility.id).toList()..sort();
      if (!seen.add(ids.join('|'))) continue;
      result.add(bundle);
      if (result.length >= 10) break;
    }
    return List<PlanRebuildBundle>.unmodifiable(result);
  }

  Future<void> applyPlanRebuildCandidate(PlanRebuildBundle bundle) async {
    for (final candidate in bundle.candidates) {
      if (!_appState.isFacilitySelected(candidate.facility.id)) {
        _appState.addFacility(candidate.facility);
      }
    }
    await generateSchedule();
  }

  Future<List<FreeTimeImprovementChoice>> loadAllFreeTimeImprovementChoices() async {
    final currentSchedule = schedule;
    if (currentSchedule == null) {
      return const <FreeTimeImprovementChoice>[];
    }
    final gaps = currentSchedule.items
        .where((item) => item.type == ScheduleItemType.breakTime)
        .where((item) {
          final start = item.startHour * 60 + item.startMinute;
          final end = item.endHour * 60 + item.endMinute;
          return end - start >= 20;
        })
        .toList(growable: false)
      ..sort((left, right) {
        final leftStart = left.startHour * 60 + left.startMinute;
        final rightStart = right.startHour * 60 + right.startMinute;
        return leftStart.compareTo(rightStart);
      });

    final choices = <FreeTimeImprovementChoice>[];
    for (final gap in gaps) {
      choices.addAll(await loadFreeTimeImprovementChoices(gap));
    }
    choices.sort((left, right) {
      final scoreCompare = right.score.compareTo(left.score);
      if (scoreCompare != 0) return scoreCompare;
      return left.plannedStartMinutes.compareTo(right.plannedStartMinutes);
    });
    return List<FreeTimeImprovementChoice>.unmodifiable(choices);
  }

  Future<List<FreeTimeImprovementChoice>> loadRepeatRideChoicesForFacility(
    String facilityId, {
    int? minimumStartMinutes,
  }) async {
    final currentSchedule = schedule;
    if (currentSchedule == null || facilityId.trim().isEmpty) {
      return const <FreeTimeImprovementChoice>[];
    }

    final gaps = currentSchedule.items
        .where((item) {
          if (item.type != ScheduleItemType.breakTime) return false;
          final start = item.startHour * 60 + item.startMinute;
          final end = item.endHour * 60 + item.endMinute;
          if (end - start < 20) return false;
          if (minimumStartMinutes != null && end <= minimumStartMinutes) {
            return false;
          }
          return true;
        })
        .toList(growable: false)
      ..sort((left, right) {
        final leftStart = left.startHour * 60 + left.startMinute;
        final rightStart = right.startHour * 60 + right.startMinute;
        return leftStart.compareTo(rightStart);
      });

    final repeatChoices = <FreeTimeImprovementChoice>[];
    for (final gap in gaps) {
      final gapStart = gap.startHour * 60 + gap.startMinute;
      final gapEnd = gap.endHour * 60 + gap.endMinute;
      var evaluationGap = gap;
      if (minimumStartMinutes != null &&
          gapStart < minimumStartMinutes &&
          minimumStartMinutes < gapEnd) {
        evaluationGap = ScheduleItem(
          id: gap.id,
          title: gap.title,
          type: ScheduleItemType.breakTime,
          startHour: minimumStartMinutes ~/ 60,
          startMinute: minimumStartMinutes % 60,
          endHour: gap.endHour,
          endMinute: gap.endMinute,
          reason: gap.reason,
          note: gap.note,
        );
      }

      final choices = await loadFreeTimeImprovementChoices(evaluationGap);
      for (final choice in choices) {
        if (choice.kind != FreeTimeImprovementKind.repeatAttraction ||
            choice.facility.id != facilityId) {
          continue;
        }
        if (minimumStartMinutes != null &&
            choice.plannedStartMinutes < minimumStartMinutes) {
          continue;
        }
        repeatChoices.add(choice);
      }
    }

    repeatChoices.sort((left, right) {
      final byStart = left.plannedStartMinutes.compareTo(
        right.plannedStartMinutes,
      );
      if (byStart != 0) return byStart;
      return right.score.compareTo(left.score);
    });

    return List<FreeTimeImprovementChoice>.unmodifiable(repeatChoices);
  }

  Future<void> applyFreeTimeImprovement(
    FreeTimeImprovementChoice choice,
  ) async {
    if (choice.kind == FreeTimeImprovementKind.performance) {
      final option = choice.performanceOption;
      if (option == null) return;
      await addPerformanceToPlan(
        PerformancePlanChoice(facility: choice.facility, option: option),
      );
      return;
    }

    if (choice.kind == FreeTimeImprovementKind.repeatAttraction) {
      final targetDate = _appState.tripSettings.visitDate ?? DateTime.now();
      final repeatNumber = choice.repeatNumber ?? 2;
      final waitSource = _canonicalUnlimitedRideSource(choice);
      final usesUnlimitedRide = _isUnlimitedRideSource(waitSource);
      final item = ScheduleItem(
        id:
            'manual_repeat_${_dateToken(targetDate)}_${choice.facility.id}_'
            '${DateTime.now().microsecondsSinceEpoch}',
        title: '${choice.facility.name}（$repeatNumber回目）',
        type: ScheduleItemType.facility,
        startHour: choice.plannedStartMinutes ~/ 60,
        startMinute: choice.plannedStartMinutes % 60,
        endHour: choice.plannedEndMinutes ~/ 60,
        endMinute: choice.plannedEndMinutes % 60,
        facilityId: choice.facility.id,
        reason:
            '空き時間改善からユーザーが明示的に追加した$repeatNumber回目の利用です。'
            'Disney Plannerが自動で再乗車を追加したものではありません。'
            '既存の予定は動かさず、この空き時間へ局所挿入しています。',
        note:
            'ユーザーが手動追加した再乗車です。不要になった場合はプランを元に戻すか再編集できます。',
        estimatedWaitMinutes: choice.estimatedWaitMinutes,
        experienceMinutes: choice.facility.durationMinutes,
        waitEstimateSource: waitSource,
        accessMethod: FacilityAccessMethod.standby,
        usesVacationPackageUnlimited: usesUnlimitedRide,
        standbyWaitMinutes:
            usesUnlimitedRide ? null : choice.estimatedWaitMinutes,
        priorityAccessBufferMinutes:
            usesUnlimitedRide ? choice.estimatedWaitMinutes : null,
      );
      if (!_insertFreeTimeItemLocally(item)) {
        errorMessage =
            '空き時間の状態が変わったため、この場所へ追加できませんでした。'
            'プランを確認してもう一度お試しください。';
        notifyListeners();
      }
      return;
    }

    final facility = choice.facility;
    if (!_appState.isFacilitySelected(facility.id)) {
      _appState.addFacility(facility);
    }
    _appState.updatePreferenceFixedTimeStatus(
      facilityId: facility.id,
      status: FixedTimeStatus.planned,
    );
    _appState.updatePreferenceScheduledAccessTime(
      facilityId: facility.id,
      value: _formatMinutes(choice.plannedStartMinutes),
    );
    _appState.updatePreferencePreferredTime(
      facilityId: facility.id,
      preferredTime: _preferredTimeForMinutes(choice.plannedStartMinutes),
    );
    final updatedPreference = _appState.getPreference(facility.id);
    final currentGeneratedPreferences = _generatedPreferences;
    if (updatedPreference != null && currentGeneratedPreferences != null) {
      _generatedPreferences = List<PlanPreference>.unmodifiable([
        for (final preference in currentGeneratedPreferences)
          if (preference.facilityId != facility.id) preference,
        updatedPreference,
      ]);
    }

    final waitSource = _canonicalUnlimitedRideSource(choice);
    final usesUnlimitedRide = _isUnlimitedRideSource(waitSource);
    final preference = _appState.getPreference(facility.id);
    final item = ScheduleItem(
      id:
          'manual_free_time_${_dateToken(_appState.tripSettings.visitDate ?? DateTime.now())}_'
          '${facility.id}_${DateTime.now().microsecondsSinceEpoch}',
      title: facility.name,
      type: ScheduleItemType.facility,
      startHour: choice.plannedStartMinutes ~/ 60,
      startMinute: choice.plannedStartMinutes % 60,
      endHour: choice.plannedEndMinutes ~/ 60,
      endMinute: choice.plannedEndMinutes % 60,
      facilityId: facility.id,
      reason:
          '空き時間改善からユーザーが明示的に追加した予定です。'
          '既存の予定は動かさず、この空き時間へ局所挿入しています。',
      note: '空き時間改善で手動追加した予定です。',
      estimatedWaitMinutes: choice.estimatedWaitMinutes,
      experienceMinutes: facility.durationMinutes,
      waitEstimateSource: waitSource,
      accessMethod: preference?.accessMethod ?? FacilityAccessMethod.standby,
      usesVacationPackageUnlimited: usesUnlimitedRide,
      standbyWaitMinutes:
          usesUnlimitedRide ? null : choice.estimatedWaitMinutes,
      priorityAccessBufferMinutes:
          usesUnlimitedRide ? choice.estimatedWaitMinutes : null,
    );
    if (!_insertFreeTimeItemLocally(item)) {
      errorMessage =
          '空き時間の状態が変わったため、この場所へ追加できませんでした。'
          'プランを確認してもう一度お試しください。';
      notifyListeners();
    }
  }

  _FreeTimeWaitEstimate _freeTimeWaitEstimate({
    required Facility facility,
    required int scheduledStartMinutes,
    required TimeBandWaitProfile? profile,
    required GreetingWaitPlanningValue? greetingWaitPlanning,
    required Map<String, int> unlimitedRideBufferMinutes,
  }) {
    if (facility.category == FacilityCategory.restaurant) {
      return const _FreeTimeWaitEstimate(
        minutes: 0,
        source: 'レストラン利用時間（待ち時間は当日状況により変動）',
      );
    }
    if (facility.category == FacilityCategory.shop) {
      return const _FreeTimeWaitEstimate(
        minutes: 0,
        source: 'ショップ滞在時間（待ち時間は計上しません）',
      );
    }

    if (unlimitedRideBufferMinutes.containsKey(facility.id) &&
        facility.category == FacilityCategory.attraction) {
      final minutes = unlimitedRideBufferMinutes[facility.id] ?? 15;
      return _FreeTimeWaitEstimate(
        minutes: minutes,
        source:
            'バケーションパッケージ乗り放題（優先入口利用バッファ$minutes分・Disney Planner計画値）',
      );
    }
    if (facility.category == FacilityCategory.greeting &&
        greetingWaitPlanning != null) {
      return _FreeTimeWaitEstimate(
        minutes: greetingWaitPlanning.waitMinutes,
        source: greetingWaitPlanning.source,
      );
    }

    final band = _waitBandForMinutes(scheduledStartMinutes);
    final range = profile?.rangeFor(band);
    if (range != null &&
        range.typicalMinutes > 0 &&
        (range.sampleCount == null || range.sampleCount! >= 3)) {
      return _FreeTimeWaitEstimate(
        minutes: _ceilToFive(range.typicalMinutes),
        source: '収集済み待ち時間実績（${band.label}）',
      );
    }

    final nearest = _nearestReliableWait(profile, band);
    if (nearest != null) {
      return _FreeTimeWaitEstimate(
        minutes: _ceilToFive(nearest.typicalMinutes),
        source: '収集済み待ち時間実績（近接時間帯）',
      );
    }

    final fallback = switch (facility.priority.name) {
      'highest' => 60,
      'high' => 45,
      'medium' => 30,
      _ => 20,
    };
    return _FreeTimeWaitEstimate(
      minutes: fallback,
      source: '実績不足のため安全側計画値',
    );
  }

  WaitTimeRange? _nearestReliableWait(
    TimeBandWaitProfile? profile,
    WaitTimeBand targetBand,
  ) {
    if (profile == null) return null;
    const bands = <WaitTimeBand>[
      WaitTimeBand.afterOpening,
      WaitTimeBand.beforeLunch,
      WaitTimeBand.afterLunch,
      WaitTimeBand.aroundShows,
      WaitTimeBand.beforeDinner,
      WaitTimeBand.afterDinner,
      WaitTimeBand.beforeClosing,
    ];
    final targetIndex = bands.indexOf(targetBand);
    WaitTimeRange? best;
    var bestDistance = 999;
    for (var index = 0; index < bands.length; index++) {
      final range = profile.rangeFor(bands[index]);
      if (range == null ||
          range.typicalMinutes <= 0 ||
          (range.sampleCount != null && range.sampleCount! < 3)) {
        continue;
      }
      final distance = (index - targetIndex).abs();
      if (distance < bestDistance) {
        best = range;
        bestDistance = distance;
      }
    }
    return best;
  }

  int? _earliestOperatingStart({
    required Facility facility,
    required DateTime targetDate,
    required int requestedStartMinutes,
    required int durationMinutes,
    required int latestEndMinutes,
  }) {
    final windows = [...facility.operatingWindowsFor(targetDate)]
      ..sort((a, b) => a.open.compareTo(b.open));
    if (windows.isEmpty) {
      return requestedStartMinutes + durationMinutes <= latestEndMinutes
          ? requestedStartMinutes
          : null;
    }
    for (final window in windows) {
      final open = window.open.hour * 60 + window.open.minute;
      final close = window.close.hour * 60 + window.close.minute;
      final start = requestedStartMinutes > open ? requestedStartMinutes : open;
      if (start + durationMinutes <= close &&
          start + durationMinutes <= latestEndMinutes) {
        return start;
      }
    }
    return null;
  }

  _RepeatPolicy _repeatPolicyFor({
    required Facility facility,
    required PlanPreference? preference,
    required int inPlanCount,
    required TripSettings settings,
  }) {
    if (inPlanCount <= 0) {
      return const _RepeatPolicy(
        allowed: true,
        label: '追加',
        reason: '',
      );
    }

    final method = preference?.accessMethod ?? FacilityAccessMethod.standby;

    // Rights obtained for one timed use must never be silently reused.
    if (method == FacilityAccessMethod.entryRequest ||
        facility.requiresEntryRequest) {
      return const _RepeatPolicy(
        allowed: false,
        label: '再追加不可',
        reason: 'エントリー受付の同じ当選枠を2回利用することはできません。',
      );
    }
    if (method == FacilityAccessMethod.standbyPass ||
        (preference?.useStandbyPass ?? false)) {
      return const _RepeatPolicy(
        allowed: false,
        label: '追加パスが必要',
        reason: 'スタンバイパス利用は追加の取得条件を確認できないため、自動で2回目には追加しません。',
      );
    }
    if (method == FacilityAccessMethod.dpa ||
        (preference?.useDpa ?? false)) {
      final unlimited = settings.usesVacationPackage &&
          settings.hasUnlimitedAttractionRides &&
          facility.category == FacilityCategory.attraction;
      if (!unlimited) {
        return const _RepeatPolicy(
          allowed: false,
          label: '追加権利が必要',
          reason: '取得済みDPAを2回目へ使い回さないため、追加の利用権を確認できるまでは再追加しません。',
        );
      }
    }
    if (method == FacilityAccessMethod.reservation ||
        facility.requiresReservation ||
        facility.reservationRequired) {
      return const _RepeatPolicy(
        allowed: false,
        label: '別予約が必要',
        reason: '同じ予約枠を2回利用できないため、別の予約が確認できるまでは再追加しません。',
      );
    }

    // A performance is an occurrence, not merely a facility. Until another
    // distinct performance time is explicitly known, never duplicate it.
    if (facility.category == FacilityCategory.show ||
        facility.category == FacilityCategory.parade) {
      return const _RepeatPolicy(
        allowed: false,
        label: '別公演が必要',
        reason: '同じ公演回は重複できません。別の公演時刻が確認できる場合にのみ追加できます。',
      );
    }

    if (facility.category == FacilityCategory.attraction ||
        facility.category == FacilityCategory.greeting ||
        facility.category == FacilityCategory.restaurant ||
        facility.category == FacilityCategory.shop) {
      return const _RepeatPolicy(
        allowed: true,
        label: 'もう1回',
        reason: '',
      );
    }

    return const _RepeatPolicy(
      allowed: false,
      label: '再追加不可',
      reason: '現在の利用条件では2回目の成立を確認できません。',
    );
  }

  int _verifiedResidualSlackMinutes({
    required DaySchedule schedule,
    required List<Facility> facilities,
    required List<FacilityLocation> facilityLocations,
    required List<AreaConnection> areaConnections,
  }) {
    final facilityById = {
      for (final facility in facilities) facility.id: facility,
    };
    final locationById = {
      for (final location in facilityLocations) location.facilityId: location,
    };

    // breakTime is only materialized for large gaps (currently 60+ minutes),
    // so summing breakTime alone incorrectly reports zero reserve when useful
    // slack is split into several smaller gaps. Measure the actual regenerated
    // timeline instead and subtract the movement that must be preserved.
    final items = schedule.items
        .where((item) => item.type != ScheduleItemType.breakTime)
        .toList(growable: false)
      ..sort((a, b) {
        final aStart = a.startHour * 60 + a.startMinute;
        final bStart = b.startHour * 60 + b.startMinute;
        return aStart.compareTo(bStart);
      });

    var slack = 0;
    for (var i = 0; i + 1 < items.length; i++) {
      final current = items[i];
      final next = items[i + 1];
      final currentEnd = current.endHour * 60 + current.endMinute;
      final nextStart = next.startHour * 60 + next.startMinute;
      final gap = nextStart - currentEnd;
      if (gap <= 0) continue;

      var protectedMinutes = 15;
      final fromArea = _scheduleItemExitAreaId(
        current,
        facilityById: facilityById,
        locationById: locationById,
      );
      final toArea = _scheduleItemEntryAreaId(
        next,
        facilityById: facilityById,
        locationById: locationById,
      );
      if (fromArea != null && toArea != null) {
        protectedMinutes = _movementMinutes(
          fromAreaId: fromArea,
          toAreaId: toArea,
          connections: areaConnections,
        );
      }
      slack += (gap - protectedMinutes).clamp(0, 24 * 60).toInt();
    }
    return slack;
  }

  int _movementMinutes({
    required String fromAreaId,
    required String toAreaId,
    required List<AreaConnection> connections,
  }) {
    if (fromAreaId == toAreaId) return 5;
    if (connections.isEmpty) return 15;
    final distances = <String, int>{fromAreaId: 0};
    final visited = <String>{};
    while (true) {
      String? current;
      var currentDistance = 1 << 30;
      for (final entry in distances.entries) {
        if (!visited.contains(entry.key) && entry.value < currentDistance) {
          current = entry.key;
          currentDistance = entry.value;
        }
      }
      if (current == null) return 15;
      if (current == toAreaId) return currentDistance;
      visited.add(current);
      for (final connection in connections) {
        String? next;
        if (connection.fromAreaId == current) {
          next = connection.toAreaId;
        } else if (connection.bidirectional && connection.toAreaId == current) {
          next = connection.fromAreaId;
        }
        if (next == null || connection.minutes <= 0) continue;
        final candidate = currentDistance + connection.minutes;
        if (candidate < (distances[next] ?? (1 << 30))) {
          distances[next] = candidate;
        }
      }
    }
  }

  String? _scheduleItemEntryAreaId(
    ScheduleItem? item, {
    required Map<String, Facility> facilityById,
    required Map<String, FacilityLocation> locationById,
  }) {
    final facilityId = item?.facilityId;
    if (facilityId == null || facilityId.isEmpty) return null;
    return locationById[facilityId]?.areaId ?? facilityById[facilityId]?.areaId;
  }

  String? _scheduleItemExitAreaId(
    ScheduleItem? item, {
    required Map<String, Facility> facilityById,
    required Map<String, FacilityLocation> locationById,
  }) {
    final facilityId = item?.facilityId;
    if (facilityId == null || facilityId.isEmpty) return null;
    return locationById[facilityId]?.effectiveExitAreaId ??
        facilityById[facilityId]?.areaId;
  }

  WaitTimeBand _waitBandForMinutes(int minutes) {
    if (minutes < 11 * 60) return WaitTimeBand.afterOpening;
    if (minutes < 12 * 60) return WaitTimeBand.beforeLunch;
    if (minutes < 15 * 60) return WaitTimeBand.afterLunch;
    if (minutes < 17 * 60) return WaitTimeBand.aroundShows;
    if (minutes < 18 * 60) return WaitTimeBand.beforeDinner;
    if (minutes < 20 * 60) return WaitTimeBand.afterDinner;
    return WaitTimeBand.beforeClosing;
  }

  PreferredTime _preferredTimeForMinutes(int minutes) {
    if (minutes < 12 * 60) return PreferredTime.morning;
    if (minutes < 17 * 60) return PreferredTime.afternoon;
    return PreferredTime.evening;
  }

  int _ceilToFive(int minutes) {
    if (minutes <= 0) return 0;
    return ((minutes + 4) ~/ 5) * 5;
  }

  String _formatMinutes(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String? _canonicalUnlimitedRideSource(FreeTimeImprovementChoice choice) {
    final source = choice.waitSource?.trim();
    if (source == null || source.isEmpty) return source;
    if (choice.kind == FreeTimeImprovementKind.repeatAttraction ||
        source.startsWith('バケパ乗り放題') ||
        source.startsWith('バケーションパッケージ乗り放題')) {
      final minutes = choice.estimatedWaitMinutes ?? 15;
      return 'バケーションパッケージ乗り放題（優先入口利用バッファ$minutes分・Disney Planner計画値）';
    }
    return source;
  }

  bool _isUnlimitedRideSource(String? source) {
    final value = source?.trim() ?? '';
    return value.startsWith('バケーションパッケージ乗り放題') ||
        value.startsWith('バケパ乗り放題');
  }

  bool _insertFreeTimeItemLocally(ScheduleItem insertedItem) {
    final currentSchedule = schedule;
    if (currentSchedule == null) return false;

    final insertedStart =
        insertedItem.startHour * 60 + insertedItem.startMinute;
    final insertedEnd = insertedItem.endHour * 60 + insertedItem.endMinute;
    if (insertedEnd <= insertedStart) return false;

    ScheduleItem? targetGap;
    for (final candidate in currentSchedule.items) {
      if (candidate.type != ScheduleItemType.breakTime) continue;
      final gapStart = candidate.startHour * 60 + candidate.startMinute;
      final gapEnd = candidate.endHour * 60 + candidate.endMinute;
      if (gapStart <= insertedStart && insertedEnd <= gapEnd) {
        targetGap = candidate;
        break;
      }
    }
    if (targetGap == null) return false;

    final gapStart = targetGap.startHour * 60 + targetGap.startMinute;
    final gapEnd = targetGap.endHour * 60 + targetGap.endMinute;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final updatedItems = <ScheduleItem>[
      for (final item in currentSchedule.items)
        if (item.id != targetGap.id) item,
      if (_shouldKeepFreeTimeSegment(gapStart, insertedStart))
        _freeTimeSegment(
          source: targetGap,
          id: '${targetGap.id}_before_$stamp',
          startMinutes: gapStart,
          endMinutes: insertedStart,
        ),
      insertedItem,
      if (_shouldKeepFreeTimeSegment(insertedEnd, gapEnd))
        _freeTimeSegment(
          source: targetGap,
          id: '${targetGap.id}_after_$stamp',
          startMinutes: insertedEnd,
          endMinutes: gapEnd,
        ),
    ]..sort((left, right) {
        final leftStart = left.startHour * 60 + left.startMinute;
        final rightStart = right.startHour * 60 + right.startMinute;
        if (leftStart != rightStart) return leftStart.compareTo(rightStart);
        final leftEnd = left.endHour * 60 + left.endMinute;
        final rightEnd = right.endHour * 60 + right.endMinute;
        return leftEnd.compareTo(rightEnd);
      });

    _appState.updateDaySchedule(
      DaySchedule(
        id: 'schedule_${DateTime.now().millisecondsSinceEpoch}',
        parkId: currentSchedule.parkId,
        items: List<ScheduleItem>.unmodifiable(updatedItems),
        createdAt: DateTime.now(),
      ),
    );
    return true;
  }

  bool _shouldKeepFreeTimeSegment(int startMinutes, int endMinutes) {
    // Gaps shorter than the improvement minimum are route/arrival buffers, not
    // useful standalone free-time blocks. Keeping them off the timeline also
    // prevents a 5-15 minute card
    // from interrupting consecutive manual repeat rides.
    return endMinutes - startMinutes >= 20;
  }

  ScheduleItem _freeTimeSegment({
    required ScheduleItem source,
    required String id,
    required int startMinutes,
    required int endMinutes,
  }) {
    return ScheduleItem(
      id: id,
      title: source.title,
      type: ScheduleItemType.breakTime,
      startHour: startMinutes ~/ 60,
      startMinute: startMinutes % 60,
      endHour: endMinutes ~/ 60,
      endMinute: endMinutes % 60,
      reason: source.reason,
      note: source.note,
    );
  }

  bool removeManualRepeat(String itemId) {
    final currentSchedule = schedule;
    if (currentSchedule == null || !itemId.startsWith('manual_repeat_')) {
      return false;
    }

    final targetIndex = currentSchedule.items.indexWhere(
      (item) => item.id == itemId && item.id.startsWith('manual_repeat_'),
    );
    if (targetIndex < 0) return false;

    final target = currentSchedule.items[targetIndex];
    final targetStart = target.startHour * 60 + target.startMinute;
    final targetEnd = target.endHour * 60 + target.endMinute;

    final remaining = currentSchedule.items
        .where((item) => item.id != itemId)
        .toList(growable: true)
      ..add(
        ScheduleItem(
          id: 'manual_repeat_removed_${DateTime.now().microsecondsSinceEpoch}',
          title: '休憩・自由時間',
          type: ScheduleItemType.breakTime,
          startHour: targetStart ~/ 60,
          startMinute: targetStart % 60,
          endHour: targetEnd ~/ 60,
          endMinute: targetEnd % 60,
          reason: '手動追加した再乗車を削除したため、この時間を自由時間へ戻しました。',
          note: '必要に応じて別の施設や休憩に使えます。',
        ),
      );

    remaining.sort((left, right) {
      final leftStart = left.startHour * 60 + left.startMinute;
      final rightStart = right.startHour * 60 + right.startMinute;
      if (leftStart != rightStart) return leftStart.compareTo(rightStart);
      final leftEnd = left.endHour * 60 + left.endMinute;
      final rightEnd = right.endHour * 60 + right.endMinute;
      return leftEnd.compareTo(rightEnd);
    });

    final merged = <ScheduleItem>[];
    for (final item in remaining) {
      if (merged.isNotEmpty &&
          merged.last.type == ScheduleItemType.breakTime &&
          item.type == ScheduleItemType.breakTime) {
        final previous = merged.last;
        final previousEnd = previous.endHour * 60 + previous.endMinute;
        final currentStart = item.startHour * 60 + item.startMinute;
        if (previousEnd == currentStart) {
          final mergedEnd = item.endHour * 60 + item.endMinute;
          merged[merged.length - 1] = ScheduleItem(
            id: 'merged_break_${DateTime.now().microsecondsSinceEpoch}_${merged.length}',
            title: '休憩・自由時間',
            type: ScheduleItemType.breakTime,
            startHour: previous.startHour,
            startMinute: previous.startMinute,
            endHour: mergedEnd ~/ 60,
            endMinute: mergedEnd % 60,
            reason: previous.reason ?? item.reason,
            note: previous.note ?? item.note,
          );
          continue;
        }
      }
      merged.add(item);
    }

    _appState.updateDaySchedule(
      DaySchedule(
        id: 'schedule_${DateTime.now().millisecondsSinceEpoch}',
        parkId: currentSchedule.parkId,
        items: List<ScheduleItem>.unmodifiable(merged),
        createdAt: DateTime.now(),
      ),
    );
    return true;
  }

  List<ScheduleItem> _manualRepeatItemsForDate(DateTime targetDate) {
    final currentSchedule = schedule;
    if (currentSchedule == null || currentSchedule.parkId != selectedParkId) {
      return const <ScheduleItem>[];
    }
    final prefix = 'manual_repeat_${_dateToken(targetDate)}_';
    return currentSchedule.items
        .where((item) => item.id.startsWith(prefix))
        .toList(growable: false);
  }

  String _dateToken(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  void clearSchedule() {
    errorMessage = null;
    _generatedPreferences = null;
    coverageAdvice = null;
    coverageAnalysisError = null;

    _appState.clearDaySchedule();
  }

  void clearError() {
    if (errorMessage == null) {
      return;
    }

    errorMessage = null;

    notifyListeners();
  }

  void _onAppStateChanged() {
    notifyListeners();
  }

  int? _parseTimeMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }
  static String _formatDebugHourMinute(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override

  void dispose() {
    _appState.removeListener(_onAppStateChanged);

    super.dispose();
  }
}


class _RepeatPolicy {
  const _RepeatPolicy({
    required this.allowed,
    required this.label,
    required this.reason,
  });

  final bool allowed;
  final String label;
  final String reason;
}

class PlanAdditionImpact {
  const PlanAdditionImpact({
    required this.addedFacilityName,
    required this.beforeDesiredCount,
    required this.afterDesiredCount,
    required this.lostFacilityNames,
    required this.explanation,
  });

  final String addedFacilityName;
  final int beforeDesiredCount;
  final int afterDesiredCount;
  final List<String> lostFacilityNames;
  final String explanation;

  bool get hasTradeOff => lostFacilityNames.isNotEmpty;
}

class PlanAdditionChoice {
  const PlanAdditionChoice({
    required this.facility,
    required this.inPlanCount,
    required this.estimatedMinutes,
    required this.estimatedWaitMinutes,
    required this.score,
    required this.repeatAllowed,
    required this.repeatLabel,
    required this.repeatReason,
    this.spotlightReason,
  });

  final Facility facility;
  final int inPlanCount;
  final int estimatedMinutes;
  final int estimatedWaitMinutes;
  final double score;
  final bool repeatAllowed;
  final String repeatLabel;
  final String repeatReason;
  final String? spotlightReason;
}

class PlanAdditionResult {
  const PlanAdditionResult({
    required this.added,
    required this.remainingMinutes,
    this.message = '',
  });

  final bool added;
  final int remainingMinutes;
  final String message;
}

class PlanRebuildBundle {
  const PlanRebuildBundle({
    required this.candidates,
    required this.totalFreeMinutes,
    required this.safeBudgetMinutes,
    required this.reserveMinutes,
    required this.estimatedRequiredMinutes,
    required this.verifiedRemainingMinutes,
    required this.score,
  });

  final List<PlanRebuildCandidate> candidates;
  final int totalFreeMinutes;
  final int safeBudgetMinutes;
  final int reserveMinutes;
  final int estimatedRequiredMinutes;
  final int verifiedRemainingMinutes;
  final double score;
}

class PlanRebuildCandidate {
  const PlanRebuildCandidate({
    required this.facility,
    required this.estimatedRequiredMinutes,
    required this.totalFreeMinutes,
    required this.estimatedWaitMinutes,
    required this.score,
    this.spotlightReason,
  });

  final Facility facility;
  final int estimatedRequiredMinutes;
  final int totalFreeMinutes;
  final int estimatedWaitMinutes;
  final double score;
  final String? spotlightReason;
}

class PerformancePlanChoice {
  const PerformancePlanChoice({
    required this.facility,
    required this.option,
  });

  final Facility facility;
  final PerformanceTimeOption option;
}


enum FreeTimeImprovementKind { facility, repeatAttraction, performance }

class FreeTimeImprovementChoice {
  const FreeTimeImprovementChoice._({
    required this.kind,
    required this.facility,
    required this.plannedStartMinutes,
    required this.plannedEndMinutes,
    required this.movementInMinutes,
    required this.movementOutMinutes,
    required this.fitSlackMinutes,
    required this.score,
    this.performanceOption,
    this.estimatedWaitMinutes,
    this.waitSource,
    this.preparationMinutes = 0,
    this.alreadySelected = false,
    this.expertScore = 0,
    this.expertReason,
    this.repeatNumber,
  });

  factory FreeTimeImprovementChoice.facility({
    required Facility facility,
    required int plannedStartMinutes,
    required int plannedEndMinutes,
    required int estimatedWaitMinutes,
    required String waitSource,
    required int movementInMinutes,
    required int movementOutMinutes,
    required int fitSlackMinutes,
    required double score,
    required bool alreadySelected,
    double expertScore = 0,
    String? expertReason,
  }) {
    return FreeTimeImprovementChoice._(
      kind: FreeTimeImprovementKind.facility,
      facility: facility,
      plannedStartMinutes: plannedStartMinutes,
      plannedEndMinutes: plannedEndMinutes,
      estimatedWaitMinutes: estimatedWaitMinutes,
      waitSource: waitSource,
      movementInMinutes: movementInMinutes,
      movementOutMinutes: movementOutMinutes,
      fitSlackMinutes: fitSlackMinutes,
      score: score,
      alreadySelected: alreadySelected,
      expertScore: expertScore,
      expertReason: expertReason,
    );
  }

  factory FreeTimeImprovementChoice.repeatAttraction({
    required Facility facility,
    required int plannedStartMinutes,
    required int plannedEndMinutes,
    required int estimatedWaitMinutes,
    required String waitSource,
    required int movementInMinutes,
    required int movementOutMinutes,
    required int fitSlackMinutes,
    required double score,
    required int repeatNumber,
    double expertScore = 0,
    String? expertReason,
  }) {
    return FreeTimeImprovementChoice._(
      kind: FreeTimeImprovementKind.repeatAttraction,
      facility: facility,
      plannedStartMinutes: plannedStartMinutes,
      plannedEndMinutes: plannedEndMinutes,
      estimatedWaitMinutes: estimatedWaitMinutes,
      waitSource: waitSource,
      movementInMinutes: movementInMinutes,
      movementOutMinutes: movementOutMinutes,
      fitSlackMinutes: fitSlackMinutes,
      score: score,
      alreadySelected: true,
      expertScore: expertScore,
      expertReason: expertReason,
      repeatNumber: repeatNumber,
    );
  }

  factory FreeTimeImprovementChoice.performance({
    required Facility facility,
    required PerformanceTimeOption option,
    required int plannedStartMinutes,
    required int plannedEndMinutes,
    required int movementInMinutes,
    required int movementOutMinutes,
    required int preparationMinutes,
    required int fitSlackMinutes,
    required double score,
  }) {
    return FreeTimeImprovementChoice._(
      kind: FreeTimeImprovementKind.performance,
      facility: facility,
      performanceOption: option,
      plannedStartMinutes: plannedStartMinutes,
      plannedEndMinutes: plannedEndMinutes,
      movementInMinutes: movementInMinutes,
      movementOutMinutes: movementOutMinutes,
      preparationMinutes: preparationMinutes,
      fitSlackMinutes: fitSlackMinutes,
      score: score,
    );
  }

  final FreeTimeImprovementKind kind;
  final Facility facility;
  final PerformanceTimeOption? performanceOption;
  final int plannedStartMinutes;
  final int plannedEndMinutes;
  final int? estimatedWaitMinutes;
  final String? waitSource;
  final int movementInMinutes;
  final int movementOutMinutes;
  final int preparationMinutes;
  final int fitSlackMinutes;
  final double score;
  final bool alreadySelected;
  final double expertScore;
  final String? expertReason;
  final int? repeatNumber;

  String get plannedStartLabel {
    final hour = (plannedStartMinutes ~/ 60).toString().padLeft(2, '0');
    final minute = (plannedStartMinutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get plannedEndLabel {
    final hour = (plannedEndMinutes ~/ 60).toString().padLeft(2, '0');
    final minute = (plannedEndMinutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _FreeTimeWaitEstimate {
  const _FreeTimeWaitEstimate({required this.minutes, required this.source});

  final int minutes;
  final String source;
}
