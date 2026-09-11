import 'package:flutter/material.dart';

import '../../app/state/app_state.dart';
import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/entities/day_schedule.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/live_operating_status.dart';
import '../../domain/entities/plan_preference.dart';
import '../../domain/entities/schedule_item.dart';
import '../../domain/enums/facility_access_method.dart';
import '../../domain/enums/facility_category.dart';
import '../facility/widgets/fixed_schedule_editor_sheet.dart';
import '../assistant/assistant_controller.dart';
import '../live/live_controller.dart';
import '../live/live_models.dart';
import '../live/widgets/live_wait_time_list_panel.dart';
import '../live/widgets/wait_time_editor.dart';
import '../plan_review/schedule_controller.dart';
import 'schedule_recalculation_controller.dart';
import 'widgets/schedule_recalculation_preview_sheet.dart';

class TodayPlanScreen extends StatefulWidget {
  const TodayPlanScreen({super.key});

  @override
  State<TodayPlanScreen> createState() {
    return _TodayPlanScreenState();
  }
}

class _TodayPlanScreenState extends State<TodayPlanScreen> {
  AppState? _appState;
  LiveController? _liveController;
  ScheduleRecalculationController? _recalculationController;
  ScheduleController? _scheduleController;
  AssistantController? _assistantController;

  late final ScrollController _mobileScrollController;
  late final ScrollController _scheduleScrollController;

  final Map<String, GlobalKey> _scheduleItemKeys = <String, GlobalKey>{};

  bool _hasScheduledInitialScroll = false;
  String? _scheduleSignature;

  @override
  void initState() {
    super.initState();

    _mobileScrollController = ScrollController();
    _scheduleScrollController = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final appState = AppStateScope.of(context);

    if (identical(_appState, appState)) {
      return;
    }

    _disposeController();

    _appState = appState;
    _liveController = LiveController(appState);
    _recalculationController = ScheduleRecalculationController(
      appState,
      _liveController!,
    );
    _scheduleController = ScheduleController(appState);
    _assistantController = AssistantController(appState);

    _liveController!.addListener(_refresh);
    _recalculationController!.addListener(_refresh);
    _scheduleController!.addListener(_refresh);
    _liveController!.initialize();
  }

  @override
  void dispose() {
    _disposeController();

    _mobileScrollController.dispose();
    _scheduleScrollController.dispose();

    super.dispose();
  }

  void _disposeController() {
    _recalculationController?.removeListener(_refresh);
    _recalculationController?.dispose();
    _scheduleController?.removeListener(_refresh);
    _scheduleController?.dispose();
    _liveController?.removeListener(_refresh);
    _liveController?.dispose();

    _assistantController?.dispose();
    _assistantController = null;
    _recalculationController = null;
    _scheduleController = null;
    _liveController = null;
  }

  void _refresh() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _scrollToCurrentSchedule({bool isInitialScroll = false}) async {
    final liveController = _liveController;

    if (liveController == null) {
      return;
    }

    final targetItemId = _currentOrNextItemId(liveController);

    if (targetItemId == null) {
      return;
    }

    final targetContext = _scheduleItemKeys[targetItemId]?.currentContext;

    if (targetContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      alignment: 0.35,
      duration: Duration(milliseconds: isInitialScroll ? 450 : 300),
      curve: Curves.easeOutCubic,
    );
  }

  String? _currentOrNextItemId(LiveController controller) {
    final schedule = controller.schedule;

    if (schedule == null || schedule.items.isEmpty) {
      return null;
    }

    final currentIndex = controller.currentOrNextIndex();

    if (currentIndex == null ||
        currentIndex < 0 ||
        currentIndex >= schedule.items.length) {
      return null;
    }

    return schedule.items[currentIndex].id;
  }

  void _synchronizeScheduleItemKeys(LiveController controller) {
    final schedule = controller.schedule;
    final items = schedule?.items ?? const <ScheduleItem>[];

    final signature = schedule == null
        ? null
        : '${schedule.parkId}|'
              '${items.map((item) => item.id).join('|')}';

    if (_scheduleSignature != signature) {
      _scheduleSignature = signature;
      _hasScheduledInitialScroll = false;
    }

    final activeIds = items.map((item) => item.id).toSet();

    _scheduleItemKeys.removeWhere((itemId, _) => !activeIds.contains(itemId));

    for (final item in items) {
      _scheduleItemKeys.putIfAbsent(item.id, GlobalKey.new);
    }
  }

  void _scheduleInitialScroll(LiveController controller) {
    final schedule = controller.schedule;

    if (_hasScheduledInitialScroll ||
        schedule == null ||
        schedule.items.isEmpty ||
        !controller.scheduleMatchesCurrentPark) {
      return;
    }

    _hasScheduledInitialScroll = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _scrollToCurrentSchedule(isInitialScroll: true);
    });
  }

  Future<void> _openWaitTimeEditor(Facility facility) async {
    final liveController = _liveController;

    if (liveController == null) {
      return;
    }

    final currentWaitTime = liveController.manualWaitTimeByFacilityId(
      facility.id,
    );

    final updatedWaitMinutes = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Material(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(sheetContext).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  WaitTimeEditor(
                    facilityId: facility.id,
                    facilityName: facility.name,
                    parkId: facility.parkId,
                    currentWaitTime: currentWaitTime,
                    isSaving: liveController.isSaving,
                    onSave: (waitMinutes) {
                      return liveController.updateWaitTime(
                        facility: facility,
                        waitMinutes: waitMinutes,
                      );
                    },
                    onClear: () {
                      return liveController.clearWaitTime(facility);
                    },
                    onSaved: (waitMinutes) async {
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop(waitMinutes);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || updatedWaitMinutes == null) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            '${facility.name}を待ち$updatedWaitMinutes分で更新しました。'
            '残り予定への影響を確認できます。',
          ),
          action: SnackBarAction(
            label: '残りを再最適化',
            onPressed: () {
              _createRecalculationProposal();
            },
          ),
        ),
      );
  }

  Future<bool> _previewAndApplyRecalculation({
    String successMessage = '再計算した予定を反映しました。',
  }) async {
    final controller = _recalculationController;
    if (controller == null) return false;
    final result = await controller.createProposal();
    if (!mounted || result == null) return false;
    final apply = await showScheduleRecalculationPreviewSheet(
      context: context,
      result: result,
    );
    if (!mounted) return false;
    if (apply) {
      controller.applyProposal();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      return true;
    }
    controller.discardProposal();
    return false;
  }

  Future<void> _createRecalculationProposal() async {
    await _previewAndApplyRecalculation(
      successMessage: '残り予定を再最適化しました。',
    );
  }

  Future<void> _suspendFacilityForToday(Facility facility) async {
    final controller = _recalculationController;
    if (controller == null || controller.isSuspended(facility.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('一時運営中止として扱いますか？'),
          content: Text(
            '${facility.name}をいったん保留にし、終了済み・進行中・食事・ショーなどを維持して、'
            'これから先だけ再最適化します。再開後は保留一覧から戻せます。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('保留して再計算'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    controller.suspendFacility(facility.id);
    final applied = await _previewAndApplyRecalculation(
      successMessage: '${facility.name}を保留し、残り予定を再最適化しました。',
    );
    if (!applied) {
      controller.resumeFacility(facility.id);
    }
  }

  Future<void> _resumeFacilityForToday(Facility facility) async {
    final controller = _recalculationController;
    final liveController = _liveController;
    if (controller == null || !controller.isSuspended(facility.id)) return;

    final liveStatus = liveController?.simulationEnabled == true
        ? null
        : liveController?.operatingStatusForFacility(facility.id);
    if (liveStatus != null &&
        liveStatus.state != LiveOperatingState.operating &&
        liveStatus.state != LiveOperatingState.unknown) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${facility.name}はライブデータ上まだ${liveStatus.state.label}です。'
            '運営状況を更新し、再開を確認してから戻してください。',
          ),
        ),
      );
      return;
    }

    controller.resumeFacility(facility.id);
    final applied = await _previewAndApplyRecalculation(
      successMessage: '${facility.name}を再開扱いに戻し、残り予定を再最適化しました。',
    );
    if (!applied) {
      controller.suspendFacility(facility.id);
    }
  }

  void _undoRecalculation() {
    final controller = _recalculationController;
    final appState = _appState;
    if (controller == null || appState == null || !controller.canUndo) return;

    controller.undoLastApply();

    if (_liveController?.simulationEnabled != true) {
      final restoredFacilityIds = appState.daySchedule?.items
              .map((item) => item.facilityId)
              .whereType<String>()
              .toSet() ??
          const <String>{};
      final restoredSuspensions = appState.liveSuspendedFacilityIds
          .where(restoredFacilityIds.contains)
          .toList(growable: false);
      for (final facilityId in restoredSuspensions) {
        appState.resumeFacilityForToday(facilityId);
      }
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('直前のスケジュールへ戻しました。')));
  }

  Future<void> _showAddPerformance() async {
    final scheduleController = _scheduleController;
    final liveController = _liveController;
    if (liveController?.simulationEnabled == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('シミュレーション中は実プランを変更する操作を無効にしています。'),
        ),
      );
      return;
    }
    final appState = _appState;
    if (scheduleController == null ||
        liveController == null ||
        appState == null ||
        scheduleController.schedule == null) {
      return;
    }

    final choices = await scheduleController.loadPerformancePlanChoices();
    if (!mounted) return;
    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('この日の追加可能なショー・パレードがありません。')),
      );
      return;
    }

    final selected = await showModalBottomSheet<PerformancePlanChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: _TodayAddPerformanceSheet(
            choices: choices,
            schedule: scheduleController.schedule!,
            minimumStartMinutes: liveController.visitPhase == LiveVisitPhase.visitDay
                ? liveController.now.hour * 60 + liveController.now.minute
                : null,
          ),
        );
      },
    );
    if (selected == null || !mounted) return;

    final originalSchedule = appState.daySchedule;
    final wasVisitDay = liveController.visitPhase == LiveVisitPhase.visitDay;
    await scheduleController.addPerformanceToPlan(selected);
    if (!mounted) return;

    if (scheduleController.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(scheduleController.errorMessage!)),
      );
      return;
    }

    final regenerated = scheduleController.schedule;
    if (wasVisitDay && originalSchedule != null && regenerated != null) {
      appState.updateDaySchedule(
        _mergePerformanceIntoLiveDay(
          original: originalSchedule,
          regenerated: regenerated,
          now: liveController.now,
        ),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${selected.option.startTime} ${selected.facility.name}を追加しました。'
          '${wasVisitDay ? '終了済み・進行中の予定は維持し、残りだけ再構成しています。' : '公演時刻を固定してプランを再生成しました。'}',
        ),
      ),
    );
  }

  DaySchedule _mergePerformanceIntoLiveDay({
    required DaySchedule original,
    required DaySchedule regenerated,
    required DateTime now,
  }) {
    final nowMinutes = now.hour * 60 + now.minute;
    final preserved = original.items.where((item) {
      final start = item.startHour * 60 + item.startMinute;
      final end = item.endHour * 60 + item.endMinute;
      if (item.type.name == 'entry') return true;
      if (item.type.name == 'exit') return false;
      return end <= nowMinutes || (start <= nowMinutes && nowMinutes < end);
    }).toList(growable: false);

    final preservedFacilityIds = preserved
        .map((item) => item.facilityId)
        .whereType<String>()
        .toSet();
    final future = regenerated.items.where((item) {
      if (item.type.name == 'entry' || item.type.name == 'exit') return false;
      if (item.facilityId != null &&
          preservedFacilityIds.contains(item.facilityId)) {
        return false;
      }
      final start = item.startHour * 60 + item.startMinute;
      return start > nowMinutes;
    });
    final exitItem = regenerated.items
        .where((item) => item.type.name == 'exit')
        .cast<ScheduleItem?>()
        .firstOrNull;

    final items = <ScheduleItem>[...preserved, ...future, ?exitItem]
      ..sort(
        (left, right) =>
            (left.startHour * 60 + left.startMinute).compareTo(
              right.startHour * 60 + right.startMinute,
            ),
      );

    return DaySchedule(
      id: 'schedule_${DateTime.now().millisecondsSinceEpoch}',
      parkId: regenerated.parkId,
      items: List<ScheduleItem>.unmodifiable(items),
      createdAt: DateTime.now(),
    );
  }

  Future<void> _openSimulationSettings() async {
    final controller = _liveController;
    if (controller == null) return;

    final visitDate = controller.visitDate;
    if (visitDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('来園日を設定してからシミュレーションを開始してください。')),
      );
      return;
    }

    var selectedTime = TimeOfDay.fromDateTime(
      controller.simulationEnabled
          ? controller.now
          : DateTime(
              visitDate.year,
              visitDate.month,
              visitDate.day,
              13,
              30,
            ),
    );

    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final enabled = controller.simulationEnabled;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.science_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '当日シミュレーション',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const Spacer(),
                      if (enabled)
                        const Chip(
                          avatar: Icon(Icons.play_circle_outline, size: 17),
                          label: Text('実行中'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '実際のプランや当日データは変更しません。仮想時刻で、一時運営中止・待ち時間更新・残り再最適化を確認できます。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('仮想現在時刻'),
                    subtitle: Text(
                      '${visitDate.month}/${visitDate.day} '
                      '${selectedTime.hour.toString().padLeft(2, '0')}:'
                      '${selectedTime.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: OutlinedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setSheetState(() {
                            selectedTime = picked;
                          });
                        }
                      },
                      child: const Text('変更'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in const [
                        (10, 30, '午前 10:30'),
                        (13, 30, '午後 13:30'),
                        (18, 30, '夜 18:30'),
                      ])
                        ActionChip(
                          label: Text(preset.$3),
                          onPressed: () {
                            setSheetState(() {
                              selectedTime = TimeOfDay(
                                hour: preset.$1,
                                minute: preset.$2,
                              );
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (enabled)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop('stop'),
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: const Text('シミュレーション終了'),
                          ),
                        ),
                      if (enabled) const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop('start'),
                          icon: Icon(
                            enabled
                                ? Icons.update_outlined
                                : Icons.play_circle_outline,
                          ),
                          label: Text(enabled ? '時刻を反映' : '開始'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'stop') {
      controller.stopSimulation();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('当日シミュレーションを終了し、実際のプラン表示へ戻しました。'),
          ),
        );
      return;
    }

    final simulatedNow = DateTime(
      visitDate.year,
      visitDate.month,
      visitDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    if (controller.simulationEnabled) {
      controller.setSimulationTime(simulatedNow);
    } else {
      controller.startSimulation(simulatedNow: simulatedNow);
    }
    _hasScheduledInitialScroll = false;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'シミュレーション開始：'
            '${selectedTime.hour.toString().padLeft(2, '0')}:'
            '${selectedTime.minute.toString().padLeft(2, '0')}。'
            '施設カードから一時運営中止や待ち時間変更を試せます。',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final liveController = _liveController;

    if (liveController == null || !liveController.isInitialized) {
      return const AppScaffold(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final snapshot = liveController.buildSnapshot();

    _synchronizeScheduleItemKeys(liveController);
    _scheduleInitialScroll(liveController);

    final recalculationController = _recalculationController;

    return AppScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useTwoColumns = constraints.maxWidth >= 900;

          if (useTwoColumns) {
            return _DesktopTodayLayout(
              controller: liveController,
              assistantController: _assistantController,
              snapshot: snapshot,
              scheduleScrollController: _scheduleScrollController,
              scheduleItemKeys: _scheduleItemKeys,
              onCurrentSchedulePressed: _scrollToCurrentSchedule,
              onWaitTimeEditPressed: _openWaitTimeEditor,
              onRecalculatePressed: _createRecalculationProposal,
              onAddPerformancePressed: _showAddPerformance,
              onUndoPressed: _undoRecalculation,
              onSuspendFacilityPressed: _suspendFacilityForToday,
              onResumeFacilityPressed: _resumeFacilityForToday,
              onSimulationPressed: _openSimulationSettings,
              isCalculating: recalculationController?.isCalculating == true,
              canUndo: recalculationController?.canUndo == true,
            );
          }

          return _MobileTodayLayout(
            controller: liveController,
            assistantController: _assistantController,
            snapshot: snapshot,
            scrollController: _mobileScrollController,
            scheduleItemKeys: _scheduleItemKeys,
            onCurrentSchedulePressed: _scrollToCurrentSchedule,
            onWaitTimeEditPressed: _openWaitTimeEditor,
            onRecalculatePressed: _createRecalculationProposal,
            onAddPerformancePressed: _showAddPerformance,
            onUndoPressed: _undoRecalculation,
            onSuspendFacilityPressed: _suspendFacilityForToday,
            onResumeFacilityPressed: _resumeFacilityForToday,
            onSimulationPressed: _openSimulationSettings,
            isCalculating: recalculationController?.isCalculating == true,
            canUndo: recalculationController?.canUndo == true,
          );
        },
      ),
    );
  }
}

class _MobileTodayLayout extends StatelessWidget {
  const _MobileTodayLayout({
    required this.controller,
    required this.assistantController,
    required this.snapshot,
    required this.scrollController,
    required this.scheduleItemKeys,
    required this.onCurrentSchedulePressed,
    required this.onWaitTimeEditPressed,
    required this.onRecalculatePressed,
    required this.onAddPerformancePressed,
    required this.onUndoPressed,
    required this.onSuspendFacilityPressed,
    required this.onResumeFacilityPressed,
    required this.onSimulationPressed,
    required this.isCalculating,
    required this.canUndo,
  });

  final LiveController controller;
  final AssistantController? assistantController;
  final LiveScheduleSnapshot snapshot;
  final ScrollController scrollController;
  final Map<String, GlobalKey> scheduleItemKeys;

  final VoidCallback onCurrentSchedulePressed;
  final ValueChanged<Facility> onWaitTimeEditPressed;
  final VoidCallback onRecalculatePressed;
  final VoidCallback onAddPerformancePressed;
  final VoidCallback onUndoPressed;
  final Future<void> Function(Facility) onSuspendFacilityPressed;
  final Future<void> Function(Facility) onResumeFacilityPressed;
  final VoidCallback onSimulationPressed;
  final bool isCalculating;
  final bool canUndo;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      interactive: true,
      thickness: 5,
      radius: const Radius.circular(8),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.only(right: 14, bottom: 96),
        children: [
          _LiveDashboardCard(
            controller: controller,
            snapshot: snapshot,
            onCurrentSchedulePressed: onCurrentSchedulePressed,
            onWaitTimeEditPressed: onWaitTimeEditPressed,
            onRecalculatePressed: onRecalculatePressed,
            onAddPerformancePressed: onAddPerformancePressed,
            onUndoPressed: onUndoPressed,
            onSimulationPressed: onSimulationPressed,
            simulationEnabled: controller.simulationEnabled,
            isCalculating: isCalculating,
            canUndo: canUndo,
          ),
          if (snapshot.isLiveMode) ...[
            const SizedBox(height: AppSpacing.sm),
            _TodayConciergeCard(controller: assistantController),
          ],
          if (controller.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _LiveErrorCard(
              message: controller.errorMessage!,
              onClose: controller.clearError,
            ),
          ],
          if (snapshot.isLiveMode) ...[
            const SizedBox(height: AppSpacing.sm),
            _CollapsibleWaitDataSection(
              controller: controller,
              now: snapshot.now,
              onEditPressed: onWaitTimeEditPressed,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _TodayScheduleContent(
            controller: controller,
            snapshot: snapshot,
            scheduleItemKeys: scheduleItemKeys,
            onWaitTimeEditPressed: onWaitTimeEditPressed,
            onRecalculatePressed: onRecalculatePressed,
            onSuspendFacilityPressed: onSuspendFacilityPressed,
            onResumeFacilityPressed: onResumeFacilityPressed,
          ),
        ],
      ),
    );
  }
}

class _DesktopTodayLayout extends StatelessWidget {
  const _DesktopTodayLayout({
    required this.controller,
    required this.assistantController,
    required this.snapshot,
    required this.scheduleScrollController,
    required this.scheduleItemKeys,
    required this.onCurrentSchedulePressed,
    required this.onWaitTimeEditPressed,
    required this.onRecalculatePressed,
    required this.onAddPerformancePressed,
    required this.onUndoPressed,
    required this.onSuspendFacilityPressed,
    required this.onResumeFacilityPressed,
    required this.onSimulationPressed,
    required this.isCalculating,
    required this.canUndo,
  });

  final LiveController controller;
  final AssistantController? assistantController;
  final LiveScheduleSnapshot snapshot;
  final ScrollController scheduleScrollController;
  final Map<String, GlobalKey> scheduleItemKeys;

  final VoidCallback onCurrentSchedulePressed;
  final ValueChanged<Facility> onWaitTimeEditPressed;
  final VoidCallback onRecalculatePressed;
  final VoidCallback onAddPerformancePressed;
  final VoidCallback onUndoPressed;
  final Future<void> Function(Facility) onSuspendFacilityPressed;
  final Future<void> Function(Facility) onResumeFacilityPressed;
  final VoidCallback onSimulationPressed;
  final bool isCalculating;
  final bool canUndo;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 370,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: AppSpacing.sm, bottom: 48),
            child: Column(
              children: [
                _LiveDashboardCard(
                  controller: controller,
                  snapshot: snapshot,
                  onCurrentSchedulePressed: onCurrentSchedulePressed,
                  onWaitTimeEditPressed: onWaitTimeEditPressed,
                  onRecalculatePressed: onRecalculatePressed,
                  onAddPerformancePressed: onAddPerformancePressed,
                  onUndoPressed: onUndoPressed,
                  onSimulationPressed: onSimulationPressed,
                  simulationEnabled: controller.simulationEnabled,
                  isCalculating: isCalculating,
                  canUndo: canUndo,
                ),
                if (snapshot.isLiveMode) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _TodayConciergeCard(controller: assistantController),
                ],
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _LiveErrorCard(
                    message: controller.errorMessage!,
                    onClose: controller.clearError,
                  ),
                ],
                if (snapshot.isLiveMode) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _CollapsibleWaitDataSection(
                    controller: controller,
                    now: snapshot.now,
                    onEditPressed: onWaitTimeEditPressed,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Scrollbar(
            controller: scheduleScrollController,
            thumbVisibility: true,
            interactive: true,
            thickness: 5,
            radius: const Radius.circular(8),
            child: ListView(
              controller: scheduleScrollController,
              padding: const EdgeInsets.only(right: 14, bottom: 48),
              children: [
                _TodayScheduleContent(
                  controller: controller,
                  snapshot: snapshot,
                  scheduleItemKeys: scheduleItemKeys,
                  onWaitTimeEditPressed: onWaitTimeEditPressed,
                  onRecalculatePressed: onRecalculatePressed,
                  onSuspendFacilityPressed: onSuspendFacilityPressed,
                  onResumeFacilityPressed: onResumeFacilityPressed,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CollapsibleWaitDataSection extends StatefulWidget {
  const _CollapsibleWaitDataSection({
    required this.controller,
    required this.now,
    required this.onEditPressed,
  });

  final LiveController controller;
  final DateTime now;
  final ValueChanged<Facility> onEditPressed;

  @override
  State<_CollapsibleWaitDataSection> createState() =>
      _CollapsibleWaitDataSectionState();
}

class _CollapsibleWaitDataSectionState
    extends State<_CollapsibleWaitDataSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        AppCard(
          child: Row(
            children: [
              Icon(Icons.query_stats_outlined, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '待ち時間・予測',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _expanded
                          ? '待ち時間一覧と予測を表示中です。'
                          : '必要なときだけ開いて確認できます。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(_expanded ? '閉じる' : '表示'),
              ),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: AppSpacing.sm),
          LiveWaitTimeListPanel(
            controller: widget.controller,
            now: widget.now,
            onEditPressed: widget.onEditPressed,
          ),
        ],
      ],
    );
  }
}

class _TodayConciergeCard extends StatefulWidget {
  const _TodayConciergeCard({required this.controller});

  final AssistantController? controller;

  @override
  State<_TodayConciergeCard> createState() => _TodayConciergeCardState();
}

class _TodayConciergeCardState extends State<_TodayConciergeCard> {
  Future<void> _ask(String question) async {
    final controller = widget.controller;
    if (controller == null) return;
    await controller.ask(question);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome),
              const SizedBox(width: 8),
              Text(
                '当日アシスタント',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('次はどこ？'),
                onPressed: controller?.isLoading == true
                    ? null
                    : () => _ask('今どこへ行けばいい？'),
              ),
              ActionChip(
                label: const Text('ショーまで何する？'),
                onPressed: controller?.isLoading == true
                    ? null
                    : () => _ask('ショーまで何をすればいい？'),
              ),
              ActionChip(
                label: const Text('休憩は必要？'),
                onPressed: controller?.isLoading == true
                    ? null
                    : () => _ask('休憩を入れた方がいい？'),
              ),
            ],
          ),
          if (controller?.isLoading == true) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ] else if (controller?.response != null) ...[
            const SizedBox(height: 8),
            Text(controller!.response!.message),
          ] else ...[
            const SizedBox(height: 8),
            const Text('今日の予定から次の行動を案内します。'),
          ],
        ],
      ),
    );
  }
}

class _LiveDashboardCard extends StatelessWidget {
  const _LiveDashboardCard({
    required this.controller,
    required this.snapshot,
    required this.onCurrentSchedulePressed,
    required this.onWaitTimeEditPressed,
    required this.onRecalculatePressed,
    required this.onAddPerformancePressed,
    required this.onUndoPressed,
    required this.onSimulationPressed,
    required this.simulationEnabled,
    required this.isCalculating,
    required this.canUndo,
  });

  final LiveController controller;
  final LiveScheduleSnapshot snapshot;
  final VoidCallback onCurrentSchedulePressed;
  final ValueChanged<Facility> onWaitTimeEditPressed;
  final VoidCallback onRecalculatePressed;
  final VoidCallback onAddPerformancePressed;
  final VoidCallback onUndoPressed;
  final VoidCallback onSimulationPressed;
  final bool simulationEnabled;
  final bool isCalculating;
  final bool canUndo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final remaining = (snapshot.totalItemCount - snapshot.completedItemCount)
        .clamp(0, snapshot.totalItemCount);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _parkIcon(controller.currentParkId),
                  size: 23,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _parkName(controller.currentParkId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      snapshot.visitDate == null
                          ? _formatCurrentDate(snapshot.now)
                          : '${_formatCurrentDate(snapshot.visitDate!)}・${_visitPhaseLabel(snapshot.visitPhase)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: snapshot.isLiveMode
                      ? colorScheme.surfaceContainerLow
                      : colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  snapshot.isLiveMode
                      ? _formatTime(snapshot.now)
                      : _visitPhaseLabel(snapshot.visitPhase),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: snapshot.isLiveMode
                        ? null
                        : colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (snapshot.isLiveMode && !simulationEnabled)
                IconButton(
                  tooltip: '現在時刻を更新',
                  onPressed: controller.refreshCurrentTime,
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: onSimulationPressed,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: simulationEnabled
                    ? const Color(0xFFFFF3E0)
                    : colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: simulationEnabled
                      ? const Color(0xFFFFB74D)
                      : colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.science_outlined,
                    size: 18,
                    color: simulationEnabled
                        ? const Color(0xFF8A4B08)
                        : colorScheme.primary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      simulationEnabled
                          ? 'シミュレーション中 ${_formatTime(snapshot.now)}'
                          : '当日シミュレーション',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    simulationEnabled ? '設定' : '試す',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _LiveMainStatusPanel(
            snapshot: snapshot,
            onWaitTimeEditPressed: onWaitTimeEditPressed,
          ),
          if (snapshot.hasSchedule &&
              snapshot.status != LiveScheduleStatus.parkMismatch) ...[
            const SizedBox(height: AppSpacing.md),
            if (snapshot.isLiveMode) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: isCalculating ? null : onRecalculatePressed,
                    icon: isCalculating
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_fix_high_outlined, size: 18),
                    label: Text(isCalculating ? '再最適化中...' : '残りを再最適化'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        simulationEnabled ? null : onAddPerformancePressed,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('ショー・パレードを追加'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onCurrentSchedulePressed,
                    icon: const Icon(Icons.my_location_outlined, size: 18),
                    label: const Text('今の予定へ'),
                  ),
                  if (canUndo)
                    TextButton.icon(
                      onPressed: onUndoPressed,
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('元に戻す'),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '予定の遅れ・待ち時間変化・一時運営中止を反映し、終了済みや固定予定を維持したまま未来部分だけ見直します。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _TodayMetricTile(
                      label: '終了',
                      value: '${snapshot.completedItemCount}件',
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TodayMetricTile(
                      label: '残り',
                      value: '$remaining件',
                      icon: Icons.route_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              _TodayProgressSummary(snapshot: snapshot),
            ] else if (snapshot.isPostVisit) ...[
              const _LiveMessagePanel(
                icon: Icons.history_outlined,
                title: '来園履歴',
                message: '来園日の記録として保存された予定を閲覧します。再計算や当日操作は行いません。',
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TodayAddPerformanceSheet extends StatelessWidget {
  const _TodayAddPerformanceSheet({
    required this.choices,
    required this.schedule,
    this.minimumStartMinutes,
  });

  final List<PerformancePlanChoice> choices;
  final DaySchedule schedule;
  final int? minimumStartMinutes;

  bool _hasExactPerformance(PerformancePlanChoice choice) {
    return schedule.items.any((item) {
      return item.facilityId == choice.facility.id &&
          item.startTimeLabel == choice.option.startTime;
    });
  }

  bool _hasOverlap(PerformancePlanChoice choice) {
    final parts = choice.option.startTime.split(':');
    if (parts.length != 2) return false;
    final start =
        (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    final end = start + choice.facility.durationMinutes;
    return schedule.items.any((item) {
      if (item.type.name == 'entry' || item.type.name == 'exit') return false;
      final itemStart = item.startHour * 60 + item.startMinute;
      final itemEnd = item.endHour * 60 + item.endMinute;
      return start < itemEnd && end > itemStart;
    });
  }

  bool _isPastPerformance(PerformancePlanChoice choice) {
    final minimum = minimumStartMinutes;
    if (minimum == null) return false;
    final parts = choice.option.startTime.split(':');
    if (parts.length != 2) return false;
    final start =
        (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    return start <= minimum;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ショー・パレードを追加'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: '閉じる',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '当日に追加する公演を選択してください。終了済み・進行中の予定は維持し、これからの予定だけを再構成します。',
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              itemCount: choices.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final choice = choices[index];
                final alreadyAdded = _hasExactPerformance(choice);
                final overlaps = _hasOverlap(choice);
                final isPast = _isPastPerformance(choice);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    child: Icon(
                      choice.facility.category == FacilityCategory.parade
                          ? Icons.celebration_outlined
                          : Icons.theater_comedy_outlined,
                    ),
                  ),
                  title: Text(choice.facility.name),
                  subtitle: Text(
                    '${choice.option.startTime} 開演・約${choice.facility.durationMinutes}分'
                    '${isPast ? '　終了済み' : overlaps && !alreadyAdded ? '　現在の予定と重なります（追加後に再調整）' : ''}',
                  ),
                  trailing: alreadyAdded
                      ? const Chip(label: Text('追加済み'))
                      : isPast
                      ? const Chip(label: Text('終了済み'))
                      : const Icon(Icons.add),
                  enabled: !alreadyAdded && !isPast,
                  onTap: alreadyAdded || isPast
                      ? null
                      : () => Navigator.of(context).pop(choice),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayMetricTile extends StatelessWidget {
  const _TodayMetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveMainStatusPanel extends StatelessWidget {
  const _LiveMainStatusPanel({
    required this.snapshot,
    required this.onWaitTimeEditPressed,
  });

  final LiveScheduleSnapshot snapshot;
  final ValueChanged<Facility> onWaitTimeEditPressed;

  @override
  Widget build(BuildContext context) {
    return switch (snapshot.status) {
      LiveScheduleStatus.noSchedule => const _LiveMessagePanel(
        icon: Icons.event_note_outlined,
        title: '実行する予定がありません',
        message: 'プラン確認画面でスケジュールを生成してください。',
      ),
      LiveScheduleStatus.parkMismatch => const _LiveMessagePanel(
        icon: Icons.sync_problem_outlined,
        title: 'パークが一致していません',
        message: '現在選択しているパークでプランを再生成してください。',
        warning: true,
      ),
      LiveScheduleStatus.completed => const _LiveMessagePanel(
        icon: Icons.celebration_outlined,
        title: 'お疲れさまでした！',
        message: '今日の予定はすべて終了しました。',
        success: true,
      ),
      LiveScheduleStatus.pastVisit => const _LiveMessagePanel(
        icon: Icons.history_outlined,
        title: '来園履歴です',
        message: '予定時刻は保存時の内容として表示します。現在時刻では進行させません。',
      ),
      LiveScheduleStatus.current => _CurrentSchedulePanel(
        snapshot: snapshot,
        onWaitTimeEditPressed: onWaitTimeEditPressed,
      ),
      LiveScheduleStatus.freeTime => _NextSchedulePanel(
        snapshot: snapshot,
        onWaitTimeEditPressed: onWaitTimeEditPressed,
        showFreeTime: true,
      ),
      LiveScheduleStatus.upcoming => _NextSchedulePanel(
        snapshot: snapshot,
        onWaitTimeEditPressed: onWaitTimeEditPressed,
        showFreeTime: false,
      ),
      LiveScheduleStatus.beforeParkOpen => _PreVisitSchedulePanel(
        snapshot: snapshot,
      ),
    };
  }
}

class _PreVisitSchedulePanel extends StatelessWidget {
  const _PreVisitSchedulePanel({required this.snapshot});

  final LiveScheduleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final item = snapshot.nextItem;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_available_outlined,
                size: 19,
                color: colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 7),
              Text(
                '来園前プレビュー',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.visitDate == null
                ? '来園前プレビュー'
                : '${snapshot.visitDate!.month}/${snapshot.visitDate!.day}の予定',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item == null
                ? '現在時刻では進行させません。'
                : '最初の予定 ${item.startTimeLabel} ${item.title}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '事前の変更は「プラン確認」で行います。来園日になると、この画面が当日実行モードへ自動で切り替わります。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentSchedulePanel extends StatelessWidget {
  const _CurrentSchedulePanel({
    required this.snapshot,
    required this.onWaitTimeEditPressed,
  });

  final LiveScheduleSnapshot snapshot;
  final ValueChanged<Facility> onWaitTimeEditPressed;

  @override
  Widget build(BuildContext context) {
    final item = snapshot.currentItem;
    if (item == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final next = snapshot.nextItem;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.play_circle_outline,
                size: 19,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 7),
              Text(
                'いま',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (snapshot.currentRemainingMinutes != null)
                Text(
                  '残り約${snapshot.currentRemainingMinutes}分',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            item.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.timeRangeLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          if (snapshot.currentWaitTime != null) ...[
            const SizedBox(height: 9),
            _WaitTimeInformationRow(
              waitTime: snapshot.currentWaitTime!,
              now: snapshot.now,
              lightForeground: true,
              isUnlimitedRide: _usesUnlimitedRideScheduleItem(item),
            ),
          ],
          if (snapshot.currentFacility != null &&
              _supportsWaitTimeUpdate(snapshot.currentFacility)) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () =>
                    onWaitTimeEditPressed(snapshot.currentFacility!),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('現在の待ち時間を更新'),
              ),
            ),
          ],
          if (next != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_forward,
                        size: 17,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '次 ${next.startTimeLabel}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      if (snapshot.minutesUntilNext != null)
                        Text(
                          'あと${snapshot.minutesUntilNext}分',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    next.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NextSchedulePanel extends StatelessWidget {
  const _NextSchedulePanel({
    required this.snapshot,
    required this.onWaitTimeEditPressed,
    required this.showFreeTime,
  });

  final LiveScheduleSnapshot snapshot;
  final ValueChanged<Facility> onWaitTimeEditPressed;
  final bool showFreeTime;

  @override
  Widget build(BuildContext context) {
    final item = snapshot.nextItem;

    if (item == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                showFreeTime
                    ? Icons.hourglass_empty_outlined
                    : Icons.upcoming_outlined,
                size: 19,
                color: colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 7),
              Text(
                showFreeTime ? '空き時間' : '次の予定',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (snapshot.minutesUntilNext != null)
                Text(
                  'あと'
                  '${snapshot.minutesUntilNext}分',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (showFreeTime && snapshot.freeTimeMinutes != null) ...[
            const SizedBox(height: 6),
            Text(
              '${snapshot.freeTimeMinutes}分の空き時間があります。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            item.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.timeRangeLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          if (snapshot.nextPreference != null) ...[
            const SizedBox(height: 8),
            _AccessMethodBadge(preference: snapshot.nextPreference!),
          ],
          if (snapshot.nextWaitTime != null) ...[
            const SizedBox(height: 9),
            _WaitTimeInformationRow(
              waitTime: snapshot.nextWaitTime!,
              now: snapshot.now,
              lightForeground: true,
              isUnlimitedRide: _usesUnlimitedRideScheduleItem(item),
            ),
          ],
          if (snapshot.nextExpectedEndAt != null) ...[
            const SizedBox(height: 7),
            Text(
              '終了予想 '
              '${_formatTime(snapshot.nextExpectedEndAt!)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (!snapshot.canCompleteNextBeforeFollowingItem) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 18,
                    color: colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '現在の待ち時間では、'
                      'その次の予定に間に合わない可能性があります。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_isProvisionalScheduleItem(item)) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '仮予定です。ショー当選・予約確定・待ち時間変化があれば、残り予定の再計算で差し替えできます。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (_supportsWaitTimeUpdate(snapshot.nextFacility)) ...[
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  onWaitTimeEditPressed(snapshot.nextFacility!);
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('待ち時間を更新'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccessMethodBadge extends StatelessWidget {
  const _AccessMethodBadge({required this.preference});

  final PlanPreference preference;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _accessMethodIcon(preference.accessMethod),
            size: 15,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 5),
          Text(
            preference.accessMethod.liveShortLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitTimeInformationRow extends StatelessWidget {
  const _WaitTimeInformationRow({
    required this.waitTime,
    required this.now,
    required this.lightForeground,
    this.isUnlimitedRide = false,
  });

  final LiveWaitTimeDisplay waitTime;
  final DateTime now;
  final bool lightForeground;
  final bool isUnlimitedRide;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final foregroundColor = lightForeground
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          waitTime.isStale
              ? Icons.warning_amber_outlined
              : Icons.groups_outlined,
          size: 17,
          color: waitTime.isStale ? colorScheme.error : foregroundColor,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                waitTime.hasWaitMinutes
                    ? isUnlimitedRide
                        ? '優先入口利用バッファ ${waitTime.waitMinutes}分'
                        : '待ち時間 ${waitTime.waitMinutes}分'
                    : isUnlimitedRide
                        ? '優先入口利用バッファ不明'
                        : '待ち時間不明',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _waitTimeSubLabel(waitTime, now),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: foregroundColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _waitTimeSubLabel(LiveWaitTimeDisplay waitTime, DateTime now) {
    if (waitTime.isStale) {
      return '要更新・${waitTime.label}';
    }

    final updatedAt = waitTime.updatedAt;

    if (updatedAt != null) {
      final difference = now.difference(updatedAt);

      if (difference.inMinutes < 1) {
        return '${waitTime.label}・たった今更新';
      }

      if (difference.inMinutes < 60) {
        return '${waitTime.label}・'
            '${difference.inMinutes}分前更新';
      }

      return '${waitTime.label}・'
          '${difference.inHours}時間前更新';
    }

    return waitTime.label;
  }
}

class _TodayProgressSummary extends StatelessWidget {
  const _TodayProgressSummary({required this.snapshot});

  final LiveScheduleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '進行状況',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${snapshot.completedItemCount}'
              ' / ${snapshot.totalItemCount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 7),
        LinearProgressIndicator(
          value: snapshot.progress,
          minHeight: 7,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

bool _usesUnlimitedRideScheduleItem(ScheduleItem item) {
  final source = item.waitEstimateSource?.trim() ?? '';
  return source.startsWith('バケーションパッケージ乗り放題') ||
      source.startsWith('バケパ乗り放題');
}

class _TodayScheduleContent extends StatefulWidget {
  const _TodayScheduleContent({
    required this.controller,
    required this.snapshot,
    required this.scheduleItemKeys,
    required this.onWaitTimeEditPressed,
    required this.onRecalculatePressed,
    required this.onSuspendFacilityPressed,
    required this.onResumeFacilityPressed,
  });

  final LiveController controller;
  final LiveScheduleSnapshot snapshot;
  final Map<String, GlobalKey> scheduleItemKeys;
  final ValueChanged<Facility> onWaitTimeEditPressed;
  final VoidCallback onRecalculatePressed;
  final Future<void> Function(Facility) onSuspendFacilityPressed;
  final Future<void> Function(Facility) onResumeFacilityPressed;

  @override
  State<_TodayScheduleContent> createState() => _TodayScheduleContentState();
}

class _TodayScheduleContentState extends State<_TodayScheduleContent> {
  bool _showCompleted = false;
  String? _loadingRepeatFacilityId;

  Future<void> _showLiveRepeatRide(Facility facility) async {
    final snapshot = widget.snapshot;
    if (!snapshot.isLiveMode || _loadingRepeatFacilityId != null) return;

    setState(() => _loadingRepeatFacilityId = facility.id);
    final appState = AppStateScope.of(context);
    final scheduleController = ScheduleController(appState);

    try {
      final nowMinutes = snapshot.now.hour * 60 + snapshot.now.minute;
      final choices = await scheduleController.loadRepeatRideChoicesForFacility(
        facility.id,
        minimumStartMinutes: nowMinutes,
      );
      if (!mounted) return;

      if (choices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('今日の残り予定には、このアトラクションをもう一度入れられる空き時間がありません。'),
          ),
        );
        return;
      }

      final selected = await showModalBottomSheet<FreeTimeImprovementChoice>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) {
          return FractionallySizedBox(
            heightFactor: 0.72,
            child: Scaffold(
              appBar: AppBar(
                title: Text('${facility.name}をもう一度'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: '閉じる',
                  ),
                ],
              ),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.xs,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Theme.of(sheetContext).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '当日の残り時間だけを対象に、既存の予定を動かさず追加できる時間を表示します。',
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        AppSpacing.lg,
                      ),
                      itemCount: choices.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final choice = choices[index];
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.repeat)),
                          title: Text(
                            '${choice.plannedStartLabel} - ${choice.plannedEndLabel}',
                          ),
                          subtitle: Text(
                            '${choice.repeatNumber ?? 2}回目として手動追加・バケパ乗り放題',
                          ),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => Navigator.of(sheetContext).pop(choice),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (selected == null || !mounted) return;

      await scheduleController.applyFreeTimeImprovement(selected);
      if (!mounted) return;
      if (scheduleController.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(scheduleController.errorMessage!)),
        );
        return;
      }

      final snackbarBottomMargin =
          MediaQuery.sizeOf(context).width >= 900 ? 144.0 : 96.0;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, snackbarBottomMargin),
          content: Text(
            '${facility.name}を${selected.repeatNumber ?? 2}回目として今日の予定へ追加しました。',
          ),
        ),
      );
    } finally {
      scheduleController.dispose();
      if (mounted) {
        setState(() => _loadingRepeatFacilityId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final snapshot = widget.snapshot;
    final schedule = controller.schedule;

    if (schedule == null) {
      return const EmptyState(
        title: '実行する予定がありません',
        message: 'プラン確認画面でスケジュールを生成してください。',
        icon: Icons.event_note_outlined,
      );
    }

    if (!controller.scheduleMatchesCurrentPark) {
      return const EmptyState(
        title: 'パークが一致していません',
        message: '現在選択しているパークでプランを再生成してください。',
        icon: Icons.sync_problem_outlined,
      );
    }

    if (schedule.items.isEmpty) {
      return const EmptyState(
        title: '予定がありません',
        message: '条件を変更し、プラン確認画面で再生成してください。',
        icon: Icons.event_busy_outlined,
      );
    }

    final suspendedFacilities = controller.suspendedFacilityIds
        .map(controller.facilityById)
        .whereType<Facility>()
        .toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));

    final completedItems = schedule.items
        .where((item) =>
            _scheduleStatus(item, snapshot.now, snapshot.visitPhase) == _TodayScheduleStatus.completed)
        .toList(growable: false);
    final remainingItems = schedule.items
        .where((item) =>
            _scheduleStatus(item, snapshot.now, snapshot.visitPhase) != _TodayScheduleStatus.completed)
        .toList(growable: false);
    final displayedItems = _showCompleted ? schedule.items : remainingItems;
    final provisionalCount = remainingItems
        .where(_isProvisionalScheduleItem)
        .length;
    final manualRepeatCount = schedule.items
        .where((item) => item.id.startsWith('manual_repeat_'))
        .length;

    ScheduleItem? latestCompletedRepeatable;
    Facility? latestCompletedRepeatableFacility;
    if (snapshot.isLiveMode) {
      for (final completed in completedItems.reversed) {
        if (!_usesUnlimitedRideScheduleItem(completed)) continue;
        final completedFacility = controller.facilityById(completed.facilityId);
        if (completedFacility?.category != FacilityCategory.attraction) continue;
        latestCompletedRepeatable = completed;
        latestCompletedRepeatableFacility = completedFacility;
        break;
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route_outlined, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snapshot.isPreVisit
                          ? snapshot.visitDate == null
                              ? '予定タイムライン'
                              : '${snapshot.visitDate!.month}/${snapshot.visitDate!.day}の予定'
                          : snapshot.isPostVisit
                          ? '来園履歴'
                          : '今日のタイムライン',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      snapshot.isPreVisit
                          ? '閲覧専用です。事前の編集はプラン確認で行ってください。'
                          : snapshot.isPostVisit
                          ? '来園日の記録として保存時の順番を表示します。'
                          : '現在時刻を基準に、進行中・次の予定・残り予定を表示します。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (snapshot.isLiveMode)
                _TodaySmallBadge(
                  icon: Icons.check_circle_outline,
                  label: '終了 ${completedItems.length}件',
                  foregroundColor: const Color(0xFF616161),
                  backgroundColor: const Color(0xFFEEEEEE),
                ),
              _TodaySmallBadge(
                icon: Icons.route_outlined,
                label: snapshot.isLiveMode
                    ? '残り ${remainingItems.length}件'
                    : manualRepeatCount == 0
                        ? '予定 ${schedule.items.length}件'
                        : '予定 ${schedule.items.length}件・手動 $manualRepeatCount件',
                foregroundColor: const Color(0xFF287A4B),
                backgroundColor: const Color(0xFFE8F5ED),
              ),
              if (provisionalCount > 0)
                _TodaySmallBadge(
                  icon: Icons.auto_awesome_outlined,
                  label: '仮予定 $provisionalCount件',
                  foregroundColor: const Color(0xFF7A5B16),
                  backgroundColor: const Color(0xFFFFF8DF),
                ),
            ],
          ),
          if (snapshot.isLiveMode && suspendedFacilities.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFCC80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.pause_circle_outline,
                        size: 20,
                        color: Color(0xFF8A4B08),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '保留中の施設',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF8A4B08),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '一時運営中止として外した施設です。再開後は、残り時間へ戻せるか再計算できます。',
                  ),
                  const SizedBox(height: 8),
                  if (!controller.simulationEnabled)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: controller.reloadWaitTimes,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('運営状況を更新'),
                      ),
                    ),
                  for (final facility in suspendedFacilities)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              facility.name,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () =>
                                widget.onResumeFacilityPressed(facility),
                            icon: const Icon(Icons.play_circle_outline, size: 18),
                            label: const Text('再開として扱う'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (snapshot.isLiveMode && completedItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showCompleted = !_showCompleted),
                icon: Icon(
                  _showCompleted ? Icons.visibility_off_outlined : Icons.history,
                  size: 18,
                ),
                label: Text(
                  _showCompleted
                      ? '終了済みを隠す'
                      : '終了済み${completedItems.length}件も表示',
                ),
              ),
            ),
          ],
          if (snapshot.isLiveMode &&
              !controller.simulationEnabled &&
              !_showCompleted &&
              latestCompletedRepeatable != null &&
              latestCompletedRepeatableFacility != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.repeat),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'もう一度乗りたい？',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${latestCompletedRepeatable.title}の空き枠を探せます。',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _loadingRepeatFacilityId == null
                        ? () => _showLiveRepeatRide(
                              latestCompletedRepeatableFacility!,
                            )
                        : null,
                    icon: _loadingRepeatFacilityId ==
                            latestCompletedRepeatableFacility.id
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.repeat, size: 18),
                    label: const Text('もう一度乗る'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (displayedItems.isEmpty)
            const _LiveMessagePanel(
              icon: Icons.celebration_outlined,
              title: '今日の予定は終了しました',
              message: '終了済みの予定は上のボタンから確認できます。',
              success: true,
            )
          else
            for (var index = 0; index < displayedItems.length; index++) ...[
              if (index > 0) ...[
                if (_visibleBufferMinutes(
                      displayedItems[index - 1],
                      displayedItems[index],
                    ) >=
                    30)
                  _TodayBufferGapCard(
                    startMinutes:
                        _scheduleEndMinutes(displayedItems[index - 1]),
                    endMinutes: _scheduleStartMinutes(displayedItems[index]),
                  )
                else if (_visibleBufferMinutes(
                          displayedItems[index - 1],
                          displayedItems[index],
                        ) >=
                        15)
                  _TodayCompactBufferGap(
                    minutes: _visibleBufferMinutes(
                      displayedItems[index - 1],
                      displayedItems[index],
                    ),
                  ),
              ],
              _TodayScheduleItemCard(
                key: widget.scheduleItemKeys[displayedItems[index].id],
                item: displayedItems[index],
                facility: controller.facilityById(
                  displayedItems[index].facilityId,
                ),
                preference: controller.preferenceByFacilityId(
                  displayedItems[index].facilityId,
                ),
                waitTime: _waitTimeForItem(
                  controller: controller,
                  item: displayedItems[index],
                ),
                now: snapshot.now,
                visitPhase: snapshot.visitPhase,
                allowLiveEdit: snapshot.isLiveMode,
                simulationEnabled: controller.simulationEnabled,
                isLast: index == displayedItems.length - 1,
                repeatRideLoading: _loadingRepeatFacilityId ==
                    controller.facilityById(displayedItems[index].facilityId)?.id,
                operatingStatus: controller.operatingStatusForFacility(
                  displayedItems[index].facilityId,
                ),
                onWaitTimeEditPressed: widget.onWaitTimeEditPressed,
                onRecalculatePressed: widget.onRecalculatePressed,
                onSuspendFacilityPressed: widget.onSuspendFacilityPressed,
                onRepeatRidePressed: _showLiveRepeatRide,
              ),
            ],
        ],
      ),
    );
  }

  LiveWaitTimeDisplay? _waitTimeForItem({
    required LiveController controller,
    required ScheduleItem item,
  }) {
    final facility = controller.facilityById(item.facilityId);
    if (!_supportsWaitTimeUpdate(facility)) return null;

    if (_usesUnlimitedRideScheduleItem(item) &&
        item.estimatedWaitMinutes != null) {
      return LiveWaitTimeDisplay(
        kind: LiveWaitTimeKind.passEstimate,
        label: 'バケパ乗り放題・優先入口利用バッファ',
        waitMinutes: item.estimatedWaitMinutes,
        isStale: false,
      );
    }

    if (!controller.canUseLiveOperations) {
      if (item.estimatedWaitMinutes != null) {
        return LiveWaitTimeDisplay(
          kind: LiveWaitTimeKind.facilityEstimate,
          label: facility!.category == FacilityCategory.greeting
              ? 'グリーティング計画値'
              : '来園日プランの計画値',
          waitMinutes: item.estimatedWaitMinutes,
          isStale: false,
        );
      }
      return const LiveWaitTimeDisplay(
        kind: LiveWaitTimeKind.unknown,
        label: '来園日前は現在値を使用しません',
        waitMinutes: null,
        isStale: false,
      );
    }

    final simulatedWaitMinutes =
        controller.simulationWaitMinutesForFacility(facility!.id);
    if (simulatedWaitMinutes != null) {
      return LiveWaitTimeDisplay(
        kind: LiveWaitTimeKind.manual,
        label: 'シミュレーション・仮想通常待機',
        waitMinutes: simulatedWaitMinutes,
        isStale: false,
      );
    }

    final manualWaitTime = controller.manualWaitTimeByFacilityId(facility.id);
    if (manualWaitTime != null) {
      return LiveWaitTimeDisplay(
        kind: LiveWaitTimeKind.manual,
        label: '手動入力',
        waitMinutes: manualWaitTime.waitMinutes,
        isStale: manualWaitTime.isStaleAt(controller.now),
        updatedAt: manualWaitTime.updatedAt,
      );
    }

    final facilityWaitTime = facility.waitTime?.minutes;
    if (facilityWaitTime != null) {
      return LiveWaitTimeDisplay(
        kind: LiveWaitTimeKind.facilityEstimate,
        label: '施設データの目安',
        waitMinutes: facilityWaitTime,
        isStale: false,
      );
    }

    if (item.estimatedWaitMinutes != null) {
      return LiveWaitTimeDisplay(
        kind: LiveWaitTimeKind.facilityEstimate,
        label: 'プラン作成時の計画値',
        waitMinutes: item.estimatedWaitMinutes,
        isStale: false,
      );
    }

    return const LiveWaitTimeDisplay(
      kind: LiveWaitTimeKind.unknown,
      label: '待ち時間不明',
      waitMinutes: null,
      isStale: false,
    );
  }
}

int _scheduleStartMinutes(ScheduleItem item) {
  return item.startHour * 60 + item.startMinute;
}

int _scheduleEndMinutes(ScheduleItem item) {
  return item.endHour * 60 + item.endMinute;
}

int _visibleBufferMinutes(ScheduleItem previous, ScheduleItem next) {
  final gap = _scheduleStartMinutes(next) - _scheduleEndMinutes(previous);
  return gap > 0 ? gap : 0;
}

String _minutesToClockLabel(int minutes) {
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _TodayCompactBufferGap extends StatelessWidget {
  const _TodayCompactBufferGap({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 6),
      child: Row(
        children: [
          Icon(
            Icons.directions_walk_outlined,
            size: 15,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            '移動・余裕 $minutes分',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _TodayBufferGapCard extends StatelessWidget {
  const _TodayBufferGapCard({
    required this.startMinutes,
    required this.endMinutes,
  });

  final int startMinutes;
  final int endMinutes;

  @override
  Widget build(BuildContext context) {
    final minutes = endMinutes - startMinutes;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.directions_walk_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '移動・余裕時間 $minutes分'
                '（${_minutesToClockLabel(startMinutes)} - ${_minutesToClockLabel(endMinutes)}）',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayScheduleItemCard extends StatefulWidget {
  const _TodayScheduleItemCard({
    super.key,
    required this.item,
    required this.facility,
    required this.preference,
    required this.waitTime,
    required this.now,
    required this.visitPhase,
    required this.allowLiveEdit,
    required this.simulationEnabled,
    required this.isLast,
    required this.repeatRideLoading,
    required this.operatingStatus,
    required this.onWaitTimeEditPressed,
    required this.onRecalculatePressed,
    required this.onSuspendFacilityPressed,
    required this.onRepeatRidePressed,
  });

  final ScheduleItem item;
  final Facility? facility;
  final PlanPreference? preference;
  final LiveWaitTimeDisplay? waitTime;

  final DateTime now;
  final LiveVisitPhase visitPhase;
  final bool allowLiveEdit;
  final bool simulationEnabled;
  final bool isLast;
  final bool repeatRideLoading;
  final LiveOperatingStatus? operatingStatus;

  final ValueChanged<Facility> onWaitTimeEditPressed;
  final VoidCallback onRecalculatePressed;
  final Future<void> Function(Facility) onSuspendFacilityPressed;
  final Future<void> Function(Facility) onRepeatRidePressed;

  @override
  State<_TodayScheduleItemCard> createState() {
    return _TodayScheduleItemCardState();
  }
}

class _TodayScheduleItemCardState extends State<_TodayScheduleItemCard> {
  bool _isExpanded = false;

  ScheduleItem get item {
    return widget.item;
  }

  bool get _hasDetails {
    return (item.reason?.trim().isNotEmpty ?? false) ||
        (item.note?.trim().isNotEmpty ?? false);
  }

  bool get _usesUnlimitedRide {
    return _usesUnlimitedRideScheduleItem(item);
  }

  bool get _hasOperatingDisruption {
    final operatingStatus = widget.operatingStatus;
    if (operatingStatus == null) return false;
    return operatingStatus.state != LiveOperatingState.operating &&
        operatingStatus.state != LiveOperatingState.unknown;
  }

  bool get _canSuspendManually {
    final facility = widget.facility;
    if (facility == null) return false;
    return facility.category == FacilityCategory.attraction ||
        facility.category == FacilityCategory.greeting;
  }

  @override
  Widget build(BuildContext context) {
    final status = _scheduleStatus(item, widget.now, widget.visitPhase);

    final statusStyle = _statusStyle(status);

    final typeStyle = _typeStyle(item.type.name);

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.isLast ? 0 : AppSpacing.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: status == _TodayScheduleStatus.current
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: status == _TodayScheduleStatus.current
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: status == _TodayScheduleStatus.current ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: statusStyle.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.startTimeLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: statusStyle.foregroundColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    decoration:
                                        status == _TodayScheduleStatus.completed
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                            ),
                          ),
                          if (widget.allowLiveEdit &&
                              !widget.simulationEnabled &&
                              widget.facility != null &&
                              status != _TodayScheduleStatus.completed)
                            IconButton(
                              tooltip: '固定予定を編集して残りを再計算',
                              onPressed: () async {
                                final appState = AppStateScope.of(context);
                                final changed =
                                    await showFixedScheduleEditorSheet(
                                      context: context,
                                      appState: appState,
                                      facility: widget.facility!,
                                    );
                                if (!changed || !context.mounted) return;
                                widget.onRecalculatePressed();
                              },
                              icon: const Icon(Icons.edit_calendar_outlined),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _TodaySmallBadge(
                            icon: typeStyle.icon,
                            label: item.type.label,
                            foregroundColor: typeStyle.foregroundColor,
                            backgroundColor: typeStyle.backgroundColor,
                          ),
                          _TodaySmallBadge(
                            icon: statusStyle.icon,
                            label: statusStyle.label,
                            foregroundColor: statusStyle.foregroundColor,
                            backgroundColor: statusStyle.backgroundColor,
                          ),
                          if (_hasOperatingDisruption)
                            _TodaySmallBadge(
                              icon: Icons.warning_amber_outlined,
                              label: widget.operatingStatus!.state.label,
                              foregroundColor: const Color(0xFFC62828),
                              backgroundColor: const Color(0xFFFFEBEE),
                            ),
                          if (_isProvisionalScheduleItem(item))
                            const _TodaySmallBadge(
                              icon: Icons.auto_awesome_outlined,
                              label: '仮予定',
                              foregroundColor: Color(0xFF7A5B16),
                              backgroundColor: Color(0xFFFFF8DF),
                            ),
                          _TodaySmallBadge(
                            icon: Icons.schedule_outlined,
                            label: item.timeRangeLabel,
                            foregroundColor: colorScheme.onSurfaceVariant,
                            backgroundColor: colorScheme.surfaceContainerLow,
                          ),
                          if (_usesUnlimitedRide)
                            const _TodaySmallBadge(
                              icon: Icons.repeat,
                              label: 'バケパ乗り放題',
                              foregroundColor: Color(0xFF4F378B),
                              backgroundColor: Color(0xFFF1ECFF),
                            )
                          else if (widget.preference != null)
                            _TodaySmallBadge(
                              icon: _accessMethodIcon(
                                widget.preference!.accessMethod,
                              ),
                              label: widget
                                  .preference!
                                  .accessMethod
                                  .liveShortLabel,
                              foregroundColor: const Color(0xFF6750A4),
                              backgroundColor: const Color(0xFFEDE7F6),
                            ),
                          if (widget.waitTime?.waitMinutes != null)
                            _TodaySmallBadge(
                              icon: _usesUnlimitedRide
                                  ? Icons.timer_outlined
                                  : widget.waitTime!.isStale
                                      ? Icons.warning_amber_outlined
                                      : Icons.groups_outlined,
                              label: _usesUnlimitedRide
                                  ? '優先入口利用バッファ${widget.waitTime!.waitMinutes}分'
                                  : widget.visitPhase == LiveVisitPhase.preVisit
                                      ? '計画待ち${widget.waitTime!.waitMinutes}分'
                                      : '待ち${widget.waitTime!.waitMinutes}分'
                                          '${widget.waitTime!.isStale ? '・要更新' : ''}',
                              foregroundColor: _usesUnlimitedRide
                                  ? const Color(0xFF4F378B)
                                  : widget.waitTime!.isStale
                                      ? const Color(0xFFC62828)
                                      : const Color(0xFF287A4B),
                              backgroundColor: _usesUnlimitedRide
                                  ? const Color(0xFFF1ECFF)
                                  : widget.waitTime!.isStale
                                      ? const Color(0xFFFFEBEE)
                                      : const Color(0xFFE8F5ED),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.allowLiveEdit &&
                _hasOperatingDisruption &&
                status != _TodayScheduleStatus.completed) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_outlined,
                      color: Color(0xFFC62828),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.operatingStatus!.state.label}の情報があります。'
                        '終了済み・進行中の他予定や固定予定を維持し、これから先だけ組み直せます。',
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: widget.facility == null
                          ? widget.onRecalculatePressed
                          : () => widget.onSuspendFacilityPressed(
                                widget.facility!,
                              ),
                      child: const Text('保留して再最適化'),
                    ),
                  ],
                ),
              ),
            ],
            if (widget.allowLiveEdit &&
                !_usesUnlimitedRide &&
                _supportsWaitTimeUpdate(widget.facility)) ...[
              const SizedBox(height: 7),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    widget.onWaitTimeEditPressed(widget.facility!);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('待ち時間を更新'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
            if (widget.allowLiveEdit &&
                !widget.simulationEnabled &&
                _usesUnlimitedRide &&
                widget.facility?.category == FacilityCategory.attraction) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: widget.repeatRideLoading
                      ? null
                      : () => widget.onRepeatRidePressed(widget.facility!),
                  icon: widget.repeatRideLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.repeat, size: 17),
                  label: const Text('もう一度乗る'),
                ),
              ),
            ],
            if (widget.allowLiveEdit &&
                _canSuspendManually &&
                !_hasOperatingDisruption &&
                status != _TodayScheduleStatus.completed) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () =>
                      widget.onSuspendFacilityPressed(widget.facility!),
                  icon: const Icon(Icons.pause_circle_outline, size: 17),
                  label: const Text('一時運営中止として扱う'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
            if (_hasDetails) ...[
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  icon: AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down, size: 18),
                  ),
                  label: Text(_isExpanded ? '詳細を閉じる' : '理由・メモを見る'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 2),
                _TodayScheduleDetails(item: item),
              ],
            ],
          ],
        ),
      ),
    );
  }

  _TodayStatusStyle _statusStyle(_TodayScheduleStatus status) {
    return switch (status) {
      _TodayScheduleStatus.completed => const _TodayStatusStyle(
        label: '終了',
        icon: Icons.check_circle_outline,
        foregroundColor: Color(0xFF616161),
        backgroundColor: Color(0xFFEEEEEE),
      ),
      _TodayScheduleStatus.current => const _TodayStatusStyle(
        label: '進行中',
        icon: Icons.play_circle_outline,
        foregroundColor: Color(0xFF2457A6),
        backgroundColor: Color(0xFFEAF2FF),
      ),
      _TodayScheduleStatus.upcoming => const _TodayStatusStyle(
        label: '予定',
        icon: Icons.upcoming_outlined,
        foregroundColor: Color(0xFF287A4B),
        backgroundColor: Color(0xFFE8F5ED),
      ),
    };
  }

  _TodayTypeStyle _typeStyle(String typeName) {
    return switch (typeName) {
      'facility' => const _TodayTypeStyle(
        icon: Icons.place_outlined,
        foregroundColor: Color(0xFF2457A6),
        backgroundColor: Color(0xFFEAF2FF),
      ),
      'breakfast' => const _TodayTypeStyle(
        icon: Icons.free_breakfast_outlined,
        foregroundColor: Color(0xFF287A4B),
        backgroundColor: Color(0xFFE8F5ED),
      ),
      'lunch' => const _TodayTypeStyle(
        icon: Icons.lunch_dining_outlined,
        foregroundColor: Color(0xFF287A4B),
        backgroundColor: Color(0xFFE8F5ED),
      ),
      'dinner' => const _TodayTypeStyle(
        icon: Icons.dinner_dining_outlined,
        foregroundColor: Color(0xFF287A4B),
        backgroundColor: Color(0xFFE8F5ED),
      ),
      'breakTime' => const _TodayTypeStyle(
        icon: Icons.chair_outlined,
        foregroundColor: Color(0xFF7A5B16),
        backgroundColor: Color(0xFFFFF8DF),
      ),
      'entry' => const _TodayTypeStyle(
        icon: Icons.login_outlined,
        foregroundColor: Color(0xFF167B82),
        backgroundColor: Color(0xFFE4F5F5),
      ),
      'exit' => const _TodayTypeStyle(
        icon: Icons.logout_outlined,
        foregroundColor: Color(0xFF536873),
        backgroundColor: Color(0xFFEDF3F5),
      ),
      _ => const _TodayTypeStyle(
        icon: Icons.event_outlined,
        foregroundColor: Color(0xFF514F66),
        backgroundColor: Color(0xFFF7F5FC),
      ),
    };
  }
}

class _LiveMessagePanel extends StatelessWidget {
  const _LiveMessagePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.warning = false,
    this.success = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool warning;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final backgroundColor = warning
        ? colorScheme.errorContainer
        : success
        ? colorScheme.secondaryContainer
        : colorScheme.surfaceContainerLow;

    final foregroundColor = warning
        ? colorScheme.onErrorContainer
        : success
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: foregroundColor),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: foregroundColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveErrorCard extends StatelessWidget {
  const _LiveErrorCard({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: '閉じる',
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.close,
              size: 17,
              color: colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodaySmallBadge extends StatelessWidget {
  const _TodaySmallBadge({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foregroundColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayScheduleDetails extends StatelessWidget {
  const _TodayScheduleDetails({required this.item});

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final reason = item.reason?.trim();

    final note = item.note?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reason != null && reason.isNotEmpty)
            _TodayDetailRow(
              icon: Icons.lightbulb_outline,
              title: '理由',
              content: reason,
            ),
          if (reason != null &&
              reason.isNotEmpty &&
              note != null &&
              note.isNotEmpty)
            const SizedBox(height: 8),
          if (note != null && note.isNotEmpty)
            _TodayDetailRow(
              icon: Icons.note_outlined,
              title: 'メモ',
              content: note,
            ),
        ],
      ),
    );
  }
}

class _TodayDetailRow extends StatelessWidget {
  const _TodayDetailRow({
    required this.icon,
    required this.title,
    required this.content,
  });

  final IconData icon;
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 7),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$title：',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: content),
              ],
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

enum _TodayScheduleStatus { completed, current, upcoming }

class _TodayStatusStyle {
  const _TodayStatusStyle({
    required this.label,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final String label;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
}

class _TodayTypeStyle {
  const _TodayTypeStyle({
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
}

bool _supportsWaitTimeUpdate(Facility? facility) {
  if (facility == null) return false;
  return facility.category == FacilityCategory.attraction ||
      facility.category == FacilityCategory.greeting;
}

bool _isProvisionalScheduleItem(ScheduleItem item) {
  return item.title.contains('（仮予定）') ||
      (item.reason?.contains('仮予定') ?? false) ||
      (item.note?.contains('仮予定') ?? false);
}

_TodayScheduleStatus _scheduleStatus(
  ScheduleItem item,
  DateTime now,
  LiveVisitPhase visitPhase,
) {
  if (visitPhase == LiveVisitPhase.preVisit ||
      visitPhase == LiveVisitPhase.postVisit) {
    return _TodayScheduleStatus.upcoming;
  }

  final currentMinutes = now.hour * 60 + now.minute;

  final startMinutes = item.startHour * 60 + item.startMinute;

  final endMinutes = item.endHour * 60 + item.endMinute;

  if (currentMinutes >= endMinutes) {
    return _TodayScheduleStatus.completed;
  }

  if (currentMinutes >= startMinutes && currentMinutes < endMinutes) {
    return _TodayScheduleStatus.current;
  }

  return _TodayScheduleStatus.upcoming;
}

IconData _accessMethodIcon(FacilityAccessMethod method) {
  return switch (method) {
    FacilityAccessMethod.standby => Icons.groups_outlined,
    FacilityAccessMethod.dpa => Icons.bolt,
    FacilityAccessMethod.priorityPass => Icons.confirmation_number_outlined,
    FacilityAccessMethod.standbyPass => Icons.airplane_ticket_outlined,
    FacilityAccessMethod.entryRequest => Icons.how_to_reg_outlined,
    FacilityAccessMethod.reservation => Icons.event_available_outlined,
    FacilityAccessMethod.freeSeating => Icons.chair_alt_outlined,
  };
}

String _visitPhaseLabel(LiveVisitPhase phase) {
  return switch (phase) {
    LiveVisitPhase.preVisit => '来園前',
    LiveVisitPhase.visitDay => '当日',
    LiveVisitPhase.postVisit => '来園済み',
    LiveVisitPhase.dateNotSet => '来園日未設定',
  };
}

String _formatCurrentDate(DateTime value) {
  const weekdays = ['月', '火', '水', '木', '金', '土', '日'];

  return '${value.year}年'
      '${value.month}月'
      '${value.day}日'
      '（${weekdays[value.weekday - 1]}）';
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');

  final minute = value.minute.toString().padLeft(2, '0');

  return '$hour:$minute';
}

String _parkName(String parkId) {
  return switch (parkId) {
    'tokyo_disneyland' => '東京ディズニーランド',
    'tokyo_disneysea' => '東京ディズニーシー',
    _ => parkId,
  };
}

IconData _parkIcon(String parkId) {
  return switch (parkId) {
    'tokyo_disneyland' => Icons.castle_outlined,
    'tokyo_disneysea' => Icons.water_outlined,
    _ => Icons.park_outlined,
  };
}


extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
