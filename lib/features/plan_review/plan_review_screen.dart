import 'package:flutter/material.dart';

import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../domain/entities/day_schedule.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/plan_preference.dart';
import '../../domain/entities/schedule_item.dart';
import '../../domain/enums/facility_access_method.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/enums/lottery_fallback_action.dart';
import '../facility/widgets/facility_visual_style.dart';
import '../facility/widgets/fixed_schedule_editor_sheet.dart';
import 'plan_optimization_controller.dart';
import 'schedule_controller.dart';
import 'widgets/plan_optimization_sheet.dart';

class PlanReviewScreen extends StatefulWidget {
  const PlanReviewScreen({super.key});

  @override
  State<PlanReviewScreen> createState() {
    return _PlanReviewScreenState();
  }
}

class _PlanReviewScreenState extends State<PlanReviewScreen> {
  ScheduleController? _controller;
  PlanOptimizationController? _optimizationController;

  late final ScrollController _mobileScrollController;
  late final ScrollController _timelineScrollController;

  @override
  void initState() {
    super.initState();

    _mobileScrollController = ScrollController();
    _timelineScrollController = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_controller != null) {
      return;
    }

    final appState = AppStateScope.of(context);

    _controller = ScheduleController(appState);
    _controller!.addListener(_refresh);
    _optimizationController = PlanOptimizationController(appState);
    _optimizationController!.addListener(_refresh);
  }

  @override
  void dispose() {
    _controller?.removeListener(_refresh);
    _controller?.dispose();
    _optimizationController?.removeListener(_refresh);
    _optimizationController?.dispose();

    _mobileScrollController.dispose();
    _timelineScrollController.dispose();

    super.dispose();
  }

  void _refresh() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _generateSchedule() async {
    final controller = _controller;

    if (controller == null) {
      return;
    }

    await controller.generateSchedule();

    if (!mounted ||
        controller.errorMessage != null ||
        controller.schedule == null) {
      return;
    }

    final targetController = MediaQuery.sizeOf(context).width >= 900
        ? _timelineScrollController
        : _mobileScrollController;

    if (!targetController.hasClients) {
      return;
    }

    await targetController.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Future<void> _showPlanOptimization() async {
    final optimizationController = _optimizationController;
    if (optimizationController == null) {
      return;
    }

    await optimizationController.analyze();
    if (!mounted) {
      return;
    }
    final errorMessage = optimizationController.errorMessage;
    if (errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
      return;
    }
    final result = optimizationController.result;
    if (result == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: PlanOptimizationSheet(
            result: result,
            onApply: optimizationController.apply,
          ),
        );
      },
    );
  }

  Future<void> _confirmClearSchedule() async {
    final controller = _controller;

    if (controller == null || controller.schedule == null) {
      return;
    }

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('プランをクリアしますか？'),
          content: const Text(
            '現在生成されているスケジュールを削除します。'
            '選択した施設や希望条件は削除されません。',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('クリア'),
            ),
          ],
        );
      },
    );

    if (shouldClear == true) {
      controller.clearSchedule();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller == null) {
      return const AppScaffold(child: LoadingView(message: 'プラン確認画面を準備中です...'));
    }

    if (controller.isLoading) {
      return const AppScaffold(child: LoadingView(message: 'スケジュールを生成中です...'));
    }

    return AppScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useTwoColumns = constraints.maxWidth >= 900;

          if (useTwoColumns) {
            return _DesktopPlanReviewLayout(
              controller: controller,
              timelineScrollController: _timelineScrollController,
              onGeneratePressed: _generateSchedule,
              onClearPressed: _confirmClearSchedule,
              onOptimizePressed: _showPlanOptimization,
              isOptimizing: _optimizationController?.isLoading ?? false,
            );
          }

          return _MobilePlanReviewLayout(
            controller: controller,
            scrollController: _mobileScrollController,
            onGeneratePressed: _generateSchedule,
            onClearPressed: _confirmClearSchedule,
            onOptimizePressed: _showPlanOptimization,
            isOptimizing: _optimizationController?.isLoading ?? false,
          );
        },
      ),
    );
  }
}

class _MobilePlanReviewLayout extends StatelessWidget {
  const _MobilePlanReviewLayout({
    required this.controller,
    required this.scrollController,
    required this.onGeneratePressed,
    required this.onClearPressed,
    required this.onOptimizePressed,
    required this.isOptimizing,
  });

  final ScheduleController controller;
  final ScrollController scrollController;
  final VoidCallback onGeneratePressed;
  final VoidCallback onClearPressed;
  final VoidCallback onOptimizePressed;
  final bool isOptimizing;

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
          _PlanOverviewCard(
            controller: controller,
            onGeneratePressed: onGeneratePressed,
            onClearPressed: onClearPressed,
            onOptimizePressed: onOptimizePressed,
            isOptimizing: isOptimizing,
          ),
          if (controller.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _GenerationErrorCard(
              message: controller.errorMessage!,
              onClose: controller.clearError,
            ),
          ],
          if (controller.hasUnavailableSelectedFacilities) ...[
            const SizedBox(height: AppSpacing.sm),
            _UnavailableFacilityWarning(
              facilities: controller.unavailableSelectedFacilities,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _ScheduleContent(controller: controller),
        ],
      ),
    );
  }
}

class _DesktopPlanReviewLayout extends StatelessWidget {
  const _DesktopPlanReviewLayout({
    required this.controller,
    required this.timelineScrollController,
    required this.onGeneratePressed,
    required this.onClearPressed,
    required this.onOptimizePressed,
    required this.isOptimizing,
  });

  final ScheduleController controller;
  final ScrollController timelineScrollController;
  final VoidCallback onGeneratePressed;
  final VoidCallback onClearPressed;
  final VoidCallback onOptimizePressed;
  final bool isOptimizing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 340,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: AppSpacing.sm, bottom: 48),
            child: Column(
              children: [
                _PlanOverviewCard(
                  controller: controller,
                  onGeneratePressed: onGeneratePressed,
                  onClearPressed: onClearPressed,
                  onOptimizePressed: onOptimizePressed,
                  isOptimizing: isOptimizing,
                ),
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _GenerationErrorCard(
                    message: controller.errorMessage!,
                    onClose: controller.clearError,
                  ),
                ],
                if (controller.hasUnavailableSelectedFacilities) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _UnavailableFacilityWarning(
                    facilities: controller.unavailableSelectedFacilities,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Scrollbar(
            controller: timelineScrollController,
            thumbVisibility: true,
            interactive: true,
            thickness: 5,
            radius: const Radius.circular(8),
            child: ListView(
              controller: timelineScrollController,
              padding: const EdgeInsets.only(right: 14, bottom: 48),
              children: [_ScheduleContent(controller: controller)],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanOverviewCard extends StatelessWidget {
  const _PlanOverviewCard({
    required this.controller,
    required this.onGeneratePressed,
    required this.onClearPressed,
    required this.onOptimizePressed,
    required this.isOptimizing,
  });

  final ScheduleController controller;
  final VoidCallback onGeneratePressed;
  final VoidCallback onClearPressed;
  final VoidCallback onOptimizePressed;
  final bool isOptimizing;

  @override
  Widget build(BuildContext context) {
    final schedule = controller.schedule;
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(
                  controller.selectedParkIcon,
                  size: 21,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.selectedParkName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '選択施設 '
                      '${controller.selectedFacilityCount}件',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _OverviewInformationRow(
            icon: Icons.auto_awesome_outlined,
            label: schedule == null
                ? 'スケジュールは未生成です'
                : '${schedule.items.length}件の予定を生成済み',
          ),
          if (schedule != null) ...[
            const SizedBox(height: 7),
            _OverviewInformationRow(
              icon: Icons.update_outlined,
              label: '生成日時：${_formatDateTime(schedule.createdAt)}',
            ),
          ],
          if (controller.hasStaleSchedule) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '表示中のプランは別のパークで生成されています。'
                '現在のパークで再生成してください。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: controller.canGenerateSchedule
                  ? onGeneratePressed
                  : null,
              icon: Icon(
                schedule == null ? Icons.auto_awesome : Icons.refresh,
                size: 19,
              ),
              label: Text(schedule == null ? 'プランを生成' : 'プランを再生成'),
            ),
          ),
          if (schedule != null) ...[
            const SizedBox(height: 7),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: isOptimizing ? null : onOptimizePressed,
                icon: isOptimizing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.psychology_alt_outlined, size: 19),
                label: Text(isOptimizing ? 'AI改善中...' : 'AIでもっと良くする'),
              ),
            ),
            const SizedBox(height: 7),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onClearPressed,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('生成結果をクリア'),
              ),
            ),
          ],
          if (!controller.canGenerateSchedule) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'プラン編集画面で、現在のパークの施設を追加してください。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();

    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '${local.year}/$month/$day $hour:$minute';
  }
}

class _OverviewInformationRow extends StatelessWidget {
  const _OverviewInformationRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _GenerationErrorCard extends StatelessWidget {
  const _GenerationErrorCard({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
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
              size: 18,
              color: colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnavailableFacilityWarning extends StatelessWidget {
  const _UnavailableFacilityWarning({required this.facilities});

  final List<Facility> facilities;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4),
        leading: Icon(Icons.warning_amber_outlined, color: colorScheme.error),
        title: Text(
          '追加できない施設があります',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.error,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${facilities.length}件はスケジュール生成から除外されます',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: [
          for (final facility in facilities)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.block_outlined, size: 18),
              title: Text(
                facility.name,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(facility.operatingStatusDisplayLabel),
            ),
        ],
      ),
    );
  }
}

class _ScheduleContent extends StatelessWidget {
  const _ScheduleContent({required this.controller});

  final ScheduleController controller;

  @override
  Widget build(BuildContext context) {
    final schedule = controller.schedule;

    if (!controller.canGenerateSchedule) {
      return const EmptyState(
        title: '施設が選択されていません',
        message: 'プラン編集画面で、行きたい施設を追加してください。',
        icon: Icons.add_location_alt_outlined,
      );
    }

    if (schedule == null) {
      return const EmptyState(
        title: 'プランはまだ生成されていません',
        message:
            '選択施設と希望条件を確認し、'
            '「プランを生成」を押してください。',
        icon: Icons.auto_awesome_outlined,
      );
    }

    if (controller.hasStaleSchedule) {
      return const EmptyState(
        title: 'パークが変更されています',
        message:
            '現在選択中のパークに合わせて、'
            'プランを再生成してください。',
        icon: Icons.sync_problem_outlined,
      );
    }

    return _ScheduleTimeline(schedule: schedule, controller: controller);
  }
}

class _ScheduleTimeline extends StatelessWidget {
  const _ScheduleTimeline({required this.schedule, required this.controller});

  final DaySchedule schedule;
  final ScheduleController controller;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_outlined, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '一日のプラン',
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
          if (schedule.items.isEmpty)
            const EmptyState(
              title: '予定がありません',
              message: '条件を変更して、プランを再生成してください。',
            )
          else
            for (var index = 0; index < schedule.items.length; index++)
              _ScheduleTimelineItem(
                item: schedule.items[index],
                facility: controller.facilityById(
                  schedule.items[index].facilityId,
                ),
                preference: controller.preferenceByFacilityId(
                  schedule.items[index].facilityId,
                ),
                isFirst: index == 0,
                isLast: index == schedule.items.length - 1,
              ),
        ],
      ),
    );
  }
}

class _ScheduleTimelineItem extends StatefulWidget {
  const _ScheduleTimelineItem({
    required this.item,
    required this.facility,
    required this.preference,
    required this.isFirst,
    required this.isLast,
  });

  final ScheduleItem item;
  final Facility? facility;
  final PlanPreference? preference;
  final bool isFirst;
  final bool isLast;

  @override
  State<_ScheduleTimelineItem> createState() {
    return _ScheduleTimelineItemState();
  }
}

class _ScheduleTimelineItemState extends State<_ScheduleTimelineItem> {
  bool _isExpanded = false;

  ScheduleItem get item {
    return widget.item;
  }

  Facility? get facility {
    return widget.facility;
  }

  PlanPreference? get preference {
    return widget.preference;
  }

  bool get _hasDetails {
    return (item.reason?.trim().isNotEmpty ?? false) ||
        (item.note?.trim().isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final scheduleStyle = _scheduleItemStyle(item.type.name);

    final categoryStyle = facility == null
        ? null
        : FacilityVisualStyle.categoryStyle(facility!);

    final timelineColor = categoryStyle?.backgroundColor ?? scheduleStyle.color;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 68,
            child: Column(
              children: [
                Text(
                  item.startTimeLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  item.endTimeLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 28,
            child: Column(
              children: [
                if (!widget.isFirst)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colorScheme.outlineVariant,
                    ),
                  )
                else
                  const Expanded(child: SizedBox.shrink()),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: timelineColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.surface, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: timelineColor.withValues(alpha: 0.25),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                if (!widget.isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colorScheme.outlineVariant,
                    ),
                  )
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ScheduleTypeBadge(item: item, style: scheduleStyle),
                        const Spacer(),
                        Text(
                          item.timeRangeLabel,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (facility != null)
                          IconButton(
                            tooltip: '固定予定を編集して再生成',
                            onPressed: () async {
                              final appState = AppStateScope.of(context);
                              final changed =
                                  await showFixedScheduleEditorSheet(
                                    context: context,
                                    appState: appState,
                                    facility: facility!,
                                  );
                              if (!changed || !context.mounted) return;
                              final controller = ScheduleController(appState);
                              await controller.generateSchedule();
                              controller.dispose();
                            },
                            icon: const Icon(Icons.edit_calendar_outlined),
                          ),
                      ],
                    ),
                    if (facility != null) ...[
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _TimelineCategoryBadge(facility: facility!),
                          _TimelineAreaBadge(areaId: facility!.areaId),
                          ..._buildPreferenceBadges(
                            facility: facility!,
                            preference: preference,
                          ),
                        ],
                      ),
                    ],
                    if (_shouldShowLotteryFallback(
                      facility: facility,
                      preference: preference,
                    )) ...[
                      const SizedBox(height: 8),
                      _LotteryFallbackInformation(
                        action: preference!.lotteryFallbackAction,
                      ),
                    ],
                    if (_hasDetails) ...[
                      const SizedBox(height: 4),
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
                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                            ),
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
                        secondChild: _ScheduleItemDetails(item: item),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPreferenceBadges({
    required Facility facility,
    required PlanPreference? preference,
  }) {
    if (preference == null) {
      return const [];
    }

    final badges = <Widget>[];
    final isShowOrParade =
        facility.category == FacilityCategory.show ||
        facility.category == FacilityCategory.parade;

    if (isShowOrParade &&
        preference.preferredPerformanceTime.trim().isNotEmpty) {
      badges.add(
        _PreferenceBadge(
          icon: Icons.schedule_outlined,
          label: '${preference.preferredPerformanceTime} 公演',
          foregroundColor: const Color(0xFF6A3DA1),
          backgroundColor: const Color(0xFFF2EAFE),
          borderColor: const Color(0xFFC9AEEF),
        ),
      );
    }

    if (facility.isRestaurant && preference.reservationTime.trim().isNotEmpty) {
      badges.add(
        _PreferenceBadge(
          icon: Icons.event_available_outlined,
          label: '${preference.reservationTime} 予約',
          foregroundColor: const Color(0xFF287A4B),
          backgroundColor: const Color(0xFFE8F5ED),
          borderColor: const Color(0xFFA5D6B7),
        ),
      );
    }

    final accessBadge = _accessMethodBadge(
      facility: facility,
      preference: preference,
    );

    if (accessBadge != null) {
      badges.add(accessBadge);
    }

    return badges;
  }

  Widget? _accessMethodBadge({
    required Facility facility,
    required PlanPreference preference,
  }) {
    return switch (preference.accessMethod) {
      FacilityAccessMethod.standby => null,
      FacilityAccessMethod.dpa =>
        facility.supportsDpa
            ? const _PreferenceBadge(
                icon: Icons.bolt,
                label: 'DPA',
                foregroundColor: Color(0xFF0277BD),
                backgroundColor: Color(0xFFE3F2FD),
                borderColor: Color(0xFF90CAF9),
              )
            : null,
      FacilityAccessMethod.priorityPass =>
        facility.supportsPriorityPass
            ? const _PreferenceBadge(
                icon: Icons.confirmation_number_outlined,
                label: 'プライオリティパス',
                foregroundColor: Color(0xFF6750A4),
                backgroundColor: Color(0xFFEDE7F6),
                borderColor: Color(0xFFB39DDB),
              )
            : null,
      FacilityAccessMethod.standbyPass =>
        facility.supportsStandbyPass
            ? const _PreferenceBadge(
                icon: Icons.airplane_ticket_outlined,
                label: 'スタンバイパス',
                foregroundColor: Color(0xFF8A6D00),
                backgroundColor: Color(0xFFFFF8E1),
                borderColor: Color(0xFFFFD54F),
              )
            : null,
      FacilityAccessMethod.entryRequest =>
        facility.requiresEntryRequest
            ? const _PreferenceBadge(
                icon: Icons.how_to_reg_outlined,
                label: 'エントリー受付',
                foregroundColor: Color(0xFFEF6C00),
                backgroundColor: Color(0xFFFFF3E0),
                borderColor: Color(0xFFFFB74D),
              )
            : null,
      FacilityAccessMethod.reservation =>
        _supportsReservation(facility)
            ? const _PreferenceBadge(
                icon: Icons.event_available_outlined,
                label: '予約利用',
                foregroundColor: Color(0xFF287A4B),
                backgroundColor: Color(0xFFE8F5ED),
                borderColor: Color(0xFFA5D6B7),
              )
            : null,
      FacilityAccessMethod.freeSeating =>
        _isShowOrParade(facility)
            ? const _PreferenceBadge(
                icon: Icons.chair_alt_outlined,
                label: '自由席・自由鑑賞',
                foregroundColor: Color(0xFF514F66),
                backgroundColor: Color(0xFFF7F5FC),
                borderColor: Color(0xFFD5D0E0),
              )
            : null,
    };
  }

  bool _shouldShowLotteryFallback({
    required Facility? facility,
    required PlanPreference? preference,
  }) {
    if (facility == null || preference == null) {
      return false;
    }

    return facility.requiresEntryRequest &&
        preference.accessMethod == FacilityAccessMethod.entryRequest;
  }

  bool _supportsReservation(Facility facility) {
    return facility.isRestaurant ||
        facility.requiresReservation ||
        facility.reservationRequired ||
        facility.supportsPrioritySeating;
  }

  bool _isShowOrParade(Facility facility) {
    return facility.category == FacilityCategory.show ||
        facility.category == FacilityCategory.parade;
  }

  _ScheduleItemVisualStyle _scheduleItemStyle(String typeName) {
    return switch (typeName) {
      'facility' => const _ScheduleItemVisualStyle(
        icon: Icons.place_outlined,
        color: Color(0xFF2457A6),
        backgroundColor: Color(0xFFEAF2FF),
      ),
      'breakfast' => const _ScheduleItemVisualStyle(
        icon: Icons.free_breakfast_outlined,
        color: Color(0xFF287A4B),
        backgroundColor: Color(0xFFE8F5ED),
      ),
      'lunch' => const _ScheduleItemVisualStyle(
        icon: Icons.lunch_dining_outlined,
        color: Color(0xFF287A4B),
        backgroundColor: Color(0xFFE8F5ED),
      ),
      'dinner' => const _ScheduleItemVisualStyle(
        icon: Icons.dinner_dining_outlined,
        color: Color(0xFF287A4B),
        backgroundColor: Color(0xFFE8F5ED),
      ),
      'breakTime' => const _ScheduleItemVisualStyle(
        icon: Icons.chair_outlined,
        color: Color(0xFF7A5B16),
        backgroundColor: Color(0xFFFFF8DF),
      ),
      'entry' => const _ScheduleItemVisualStyle(
        icon: Icons.login_outlined,
        color: Color(0xFF167B82),
        backgroundColor: Color(0xFFE4F5F5),
      ),
      'exit' => const _ScheduleItemVisualStyle(
        icon: Icons.logout_outlined,
        color: Color(0xFF536873),
        backgroundColor: Color(0xFFEDF3F5),
      ),
      _ => const _ScheduleItemVisualStyle(
        icon: Icons.event_outlined,
        color: Color(0xFF514F66),
        backgroundColor: Color(0xFFF7F5FC),
      ),
    };
  }
}

class _ScheduleTypeBadge extends StatelessWidget {
  const _ScheduleTypeBadge({required this.item, required this.style});

  final ScheduleItem item;
  final _ScheduleItemVisualStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.color),
          const SizedBox(width: 4),
          Text(
            item.type.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: style.color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCategoryBadge extends StatelessWidget {
  const _TimelineCategoryBadge({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final style = FacilityVisualStyle.categoryStyle(facility);

    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.foregroundColor),
          const SizedBox(width: 5),
          Text(
            style.label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: style.foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineAreaBadge extends StatelessWidget {
  const _TimelineAreaBadge({required this.areaId});

  final String areaId;

  @override
  Widget build(BuildContext context) {
    final style = FacilityVisualStyle.areaStyle(areaId);

    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.foregroundColor),
          const SizedBox(width: 5),
          Text(
            style.label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: style.foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceBadge extends StatelessWidget {
  const _PreferenceBadge({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LotteryFallbackInformation extends StatelessWidget {
  const _LotteryFallbackInformation({required this.action});

  final LotteryFallbackAction action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.alt_route_outlined,
            size: 17,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '外れた場合：${action.label}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleItemDetails extends StatelessWidget {
  const _ScheduleItemDetails({required this.item});

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
            _ScheduleDetailRow(
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
            _ScheduleDetailRow(
              icon: Icons.note_outlined,
              title: 'メモ',
              content: note,
            ),
        ],
      ),
    );
  }
}

class _ScheduleDetailRow extends StatelessWidget {
  const _ScheduleDetailRow({
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

class _ScheduleItemVisualStyle {
  const _ScheduleItemVisualStyle({
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;
}
