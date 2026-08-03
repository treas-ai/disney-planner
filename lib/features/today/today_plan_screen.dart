import 'package:flutter/material.dart';

import '../../app/state/app_state.dart';
import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/plan_preference.dart';
import '../../domain/entities/schedule_item.dart';
import '../../domain/enums/facility_access_method.dart';
import '../facility/widgets/fixed_schedule_editor_sheet.dart';
import '../live/live_controller.dart';
import '../live/live_models.dart';
import '../live/widgets/live_wait_time_list_panel.dart';
import '../live/widgets/wait_time_editor.dart';
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

    _liveController!.addListener(_refresh);
    _recalculationController!.addListener(_refresh);
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
    _liveController?.removeListener(_refresh);
    _liveController?.dispose();

    _recalculationController = null;
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

  void _openWaitTimeEditor(Facility facility) {
    final liveController = _liveController;

    if (liveController == null) {
      return;
    }

    final currentWaitTime = liveController.manualWaitTimeByFacilityId(
      facility.id,
    );

    showModalBottomSheet<void>(
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
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _createRecalculationProposal() async {
    final controller = _recalculationController;
    if (controller == null) return;
    final result = await controller.createProposal();
    if (!mounted || result == null) return;
    final apply = await showScheduleRecalculationPreviewSheet(
      context: context,
      result: result,
    );
    if (!mounted) return;
    if (apply) {
      controller.applyProposal();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('再計算した予定を反映しました。')));
    } else {
      controller.discardProposal();
    }
  }

  void _undoRecalculation() {
    final controller = _recalculationController;
    if (controller == null || !controller.canUndo) return;
    controller.undoLastApply();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('直前のスケジュールへ戻しました。')));
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
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final useTwoColumns = constraints.maxWidth >= 900;

              if (useTwoColumns) {
                return _DesktopTodayLayout(
                  controller: liveController,
                  snapshot: snapshot,
                  scheduleScrollController: _scheduleScrollController,
                  scheduleItemKeys: _scheduleItemKeys,
                  onCurrentSchedulePressed: _scrollToCurrentSchedule,
                  onWaitTimeEditPressed: _openWaitTimeEditor,
                );
              }

              return _MobileTodayLayout(
                controller: liveController,
                snapshot: snapshot,
                scrollController: _mobileScrollController,
                scheduleItemKeys: _scheduleItemKeys,
                onCurrentSchedulePressed: _scrollToCurrentSchedule,
                onWaitTimeEditPressed: _openWaitTimeEditor,
              );
            },
          ),
          if (liveController.schedule != null &&
              recalculationController != null)
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (recalculationController.canUndo) ...[
                    FloatingActionButton.small(
                      heroTag: 'undo_schedule_recalculation',
                      onPressed: _undoRecalculation,
                      tooltip: '直前の再計算を元に戻す',
                      child: const Icon(Icons.undo),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FloatingActionButton.extended(
                    heroTag: 'create_schedule_recalculation',
                    onPressed: recalculationController.isCalculating
                        ? null
                        : _createRecalculationProposal,
                    icon: recalculationController.isCalculating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_fix_high_outlined),
                    label: const Text('残り予定を再計算'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileTodayLayout extends StatelessWidget {
  const _MobileTodayLayout({
    required this.controller,
    required this.snapshot,
    required this.scrollController,
    required this.scheduleItemKeys,
    required this.onCurrentSchedulePressed,
    required this.onWaitTimeEditPressed,
  });

  final LiveController controller;
  final LiveScheduleSnapshot snapshot;
  final ScrollController scrollController;
  final Map<String, GlobalKey> scheduleItemKeys;

  final VoidCallback onCurrentSchedulePressed;
  final ValueChanged<Facility> onWaitTimeEditPressed;

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
          ),
          if (controller.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _LiveErrorCard(
              message: controller.errorMessage!,
              onClose: controller.clearError,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          LiveWaitTimeListPanel(
            controller: controller,
            now: snapshot.now,
            onEditPressed: onWaitTimeEditPressed,
          ),
          const SizedBox(height: AppSpacing.sm),
          _TodayScheduleContent(
            controller: controller,
            snapshot: snapshot,
            scheduleItemKeys: scheduleItemKeys,
            onWaitTimeEditPressed: onWaitTimeEditPressed,
          ),
        ],
      ),
    );
  }
}

class _DesktopTodayLayout extends StatelessWidget {
  const _DesktopTodayLayout({
    required this.controller,
    required this.snapshot,
    required this.scheduleScrollController,
    required this.scheduleItemKeys,
    required this.onCurrentSchedulePressed,
    required this.onWaitTimeEditPressed,
  });

  final LiveController controller;
  final LiveScheduleSnapshot snapshot;
  final ScrollController scheduleScrollController;
  final Map<String, GlobalKey> scheduleItemKeys;

  final VoidCallback onCurrentSchedulePressed;
  final ValueChanged<Facility> onWaitTimeEditPressed;

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
                ),
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _LiveErrorCard(
                    message: controller.errorMessage!,
                    onClose: controller.clearError,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                LiveWaitTimeListPanel(
                  controller: controller,
                  now: snapshot.now,
                  onEditPressed: onWaitTimeEditPressed,
                ),
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
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveDashboardCard extends StatelessWidget {
  const _LiveDashboardCard({
    required this.controller,
    required this.snapshot,
    required this.onCurrentSchedulePressed,
    required this.onWaitTimeEditPressed,
  });

  final LiveController controller;
  final LiveScheduleSnapshot snapshot;

  final VoidCallback onCurrentSchedulePressed;
  final ValueChanged<Facility> onWaitTimeEditPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                      _formatCurrentDate(snapshot.now),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '現在時刻を更新',
                onPressed: controller.refreshCurrentTime,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _CurrentTimePanel(now: snapshot.now),
          const SizedBox(height: AppSpacing.sm),
          _LiveMainStatusPanel(
            snapshot: snapshot,
            onWaitTimeEditPressed: onWaitTimeEditPressed,
          ),
          if (snapshot.hasSchedule &&
              snapshot.status != LiveScheduleStatus.parkMismatch) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCurrentSchedulePressed,
                icon: const Icon(Icons.my_location_outlined, size: 18),
                label: const Text('現在・次の予定へ移動'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _TodayProgressSummary(snapshot: snapshot),
          ],
        ],
      ),
    );
  }
}

class _CurrentTimePanel extends StatelessWidget {
  const _CurrentTimePanel({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 21, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '現在時刻',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            _formatTime(now),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
        title: '当日のプランがありません',
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
      LiveScheduleStatus.current => _CurrentSchedulePanel(snapshot: snapshot),
      LiveScheduleStatus.freeTime => _NextSchedulePanel(
        snapshot: snapshot,
        onWaitTimeEditPressed: onWaitTimeEditPressed,
        showFreeTime: true,
      ),
      LiveScheduleStatus.upcoming ||
      LiveScheduleStatus.beforeParkOpen => _NextSchedulePanel(
        snapshot: snapshot,
        onWaitTimeEditPressed: onWaitTimeEditPressed,
        showFreeTime: false,
      ),
    };
  }
}

class _CurrentSchedulePanel extends StatelessWidget {
  const _CurrentSchedulePanel({required this.snapshot});

  final LiveScheduleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final item = snapshot.currentItem;

    if (item == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

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
                '現在の予定',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (snapshot.currentRemainingMinutes != null)
                Text(
                  '残り約'
                  '${snapshot.currentRemainingMinutes}分',
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
              fontWeight: FontWeight.w700,
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
          if (snapshot.nextFacility != null) ...[
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
  });

  final LiveWaitTimeDisplay waitTime;
  final DateTime now;
  final bool lightForeground;

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
                    ? '待ち時間 '
                          '${waitTime.waitMinutes}分'
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

class _TodayScheduleContent extends StatelessWidget {
  const _TodayScheduleContent({
    required this.controller,
    required this.snapshot,
    required this.scheduleItemKeys,
    required this.onWaitTimeEditPressed,
  });

  final LiveController controller;
  final LiveScheduleSnapshot snapshot;
  final Map<String, GlobalKey> scheduleItemKeys;
  final ValueChanged<Facility> onWaitTimeEditPressed;

  @override
  Widget build(BuildContext context) {
    final schedule = controller.schedule;

    if (schedule == null) {
      return const EmptyState(
        title: '当日のプランがありません',
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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today_outlined, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '当日の予定',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${schedule.items.length}件',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < schedule.items.length; index++)
            _TodayScheduleItemCard(
              key: scheduleItemKeys[schedule.items[index].id],
              item: schedule.items[index],
              facility: controller.facilityById(
                schedule.items[index].facilityId,
              ),
              preference: controller.preferenceByFacilityId(
                schedule.items[index].facilityId,
              ),
              waitTime: _waitTimeForItem(
                controller: controller,
                item: schedule.items[index],
              ),
              now: snapshot.now,
              isLast: index == schedule.items.length - 1,
              onWaitTimeEditPressed: onWaitTimeEditPressed,
            ),
        ],
      ),
    );
  }

  LiveWaitTimeDisplay? _waitTimeForItem({
    required LiveController controller,
    required ScheduleItem item,
  }) {
    final facility = controller.facilityById(item.facilityId);

    if (facility == null) {
      return null;
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

    if (facilityWaitTime == null) {
      return null;
    }

    return LiveWaitTimeDisplay(
      kind: LiveWaitTimeKind.facilityEstimate,
      label: '施設データの目安',
      waitMinutes: facilityWaitTime,
      isStale: false,
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
    required this.isLast,
    required this.onWaitTimeEditPressed,
  });

  final ScheduleItem item;
  final Facility? facility;
  final PlanPreference? preference;
  final LiveWaitTimeDisplay? waitTime;

  final DateTime now;
  final bool isLast;

  final ValueChanged<Facility> onWaitTimeEditPressed;

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

  @override
  Widget build(BuildContext context) {
    final status = _scheduleStatus(item, widget.now);

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
                          if (widget.facility != null &&
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
                                final controller = LiveController(appState);
                                controller.refreshCurrentTime();
                                await controller.regenerateRemainingSchedule();
                                controller.dispose();
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
                          _TodaySmallBadge(
                            icon: Icons.schedule_outlined,
                            label: item.timeRangeLabel,
                            foregroundColor: colorScheme.onSurfaceVariant,
                            backgroundColor: colorScheme.surfaceContainerLow,
                          ),
                          if (widget.preference != null)
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
                              icon: widget.waitTime!.isStale
                                  ? Icons.warning_amber_outlined
                                  : Icons.groups_outlined,
                              label:
                                  '待ち${widget.waitTime!.waitMinutes}分'
                                  '${widget.waitTime!.isStale ? '・要更新' : ''}',
                              foregroundColor: widget.waitTime!.isStale
                                  ? const Color(0xFFC62828)
                                  : const Color(0xFF287A4B),
                              backgroundColor: widget.waitTime!.isStale
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
            if (widget.facility != null) ...[
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
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 180),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: _TodayScheduleDetails(item: item),
              ),
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

_TodayScheduleStatus _scheduleStatus(ScheduleItem item, DateTime now) {
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
