import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import '../../domain/entities/schedule_validation_issue.dart';
import '../../domain/services/plan_text_exporter.dart';
import '../../domain/enums/facility_access_method.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/enums/lottery_fallback_action.dart';
import '../../domain/enums/fixed_time_status.dart';
import '../../domain/enums/schedule_validation_severity.dart';
import '../facility/widgets/facility_visual_style.dart';
import '../facility/widgets/fixed_schedule_editor_sheet.dart';
import 'schedule_controller.dart';

class PlanReviewScreen extends StatefulWidget {
  const PlanReviewScreen({super.key});

  @override
  State<PlanReviewScreen> createState() {
    return _PlanReviewScreenState();
  }
}

class _PlanReviewScreenState extends State<PlanReviewScreen> {
  ScheduleController? _controller;

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
  }

  @override
  void dispose() {
    _controller?.removeListener(_refresh);
    _controller?.dispose();
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

    await controller.generateSchedule(preserveManualFixedItems: false);

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

  Future<void> _showAddScheduleItem() async {
    final controller = _controller;
    if (controller == null || controller.schedule == null) {
      return;
    }

    final choices = await controller.loadPerformancePlanChoices();
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
          child: _AddPerformanceSheet(
            choices: choices,
            schedule: controller.schedule!,
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    await controller.addPerformanceToPlan(selected);

    if (!mounted) return;
    if (controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.errorMessage!)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${selected.option.startTime} ${selected.facility.name}を固定予定として追加し、プランを再生成しました。',
        ),
      ),
    );
  }

  Future<void> _showPlanTextExport() async {
    final controller = _controller;
    final schedule = controller?.schedule;

    if (controller == null || schedule == null) {
      return;
    }

    final appState = AppStateScope.of(context);
    const exporter = PlanTextExporter();

    final simpleText = exporter.export(
      schedule: schedule,
      settings: appState.tripSettings,
      parkName: controller.selectedParkName,
      preferences: controller.preferencesForExport,
      validationIssues: controller.validationIssues,
      format: PlanTextExportFormat.simple,
    );
    final evaluationText = exporter.export(
      schedule: schedule,
      settings: appState.tripSettings,
      parkName: controller.selectedParkName,
      preferences: controller.preferencesForExport,
      validationIssues: controller.validationIssues,
      format: PlanTextExportFormat.evaluation,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _PlanTextExportDialog(
          simpleText: simpleText,
          evaluationText: evaluationText,
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
              onExportPressed: _showPlanTextExport,
              onAddScheduleItemPressed: _showAddScheduleItem,
            );
          }

          return _MobilePlanReviewLayout(
            controller: controller,
            scrollController: _mobileScrollController,
            onGeneratePressed: _generateSchedule,
            onClearPressed: _confirmClearSchedule,
            onExportPressed: _showPlanTextExport,
            onAddScheduleItemPressed: _showAddScheduleItem,
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
    required this.onExportPressed,
    required this.onAddScheduleItemPressed,
  });

  final ScheduleController controller;
  final ScrollController scrollController;
  final VoidCallback onGeneratePressed;
  final VoidCallback onClearPressed;
  final VoidCallback onExportPressed;
  final VoidCallback onAddScheduleItemPressed;

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
            onExportPressed: onExportPressed,
            onAddScheduleItemPressed: onAddScheduleItemPressed,
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
          if (controller.validationIssues.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _ScheduleValidationCard(issues: controller.validationIssues),
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
    required this.onExportPressed,
    required this.onAddScheduleItemPressed,
  });

  final ScheduleController controller;
  final ScrollController timelineScrollController;
  final VoidCallback onGeneratePressed;
  final VoidCallback onClearPressed;
  final VoidCallback onExportPressed;
  final VoidCallback onAddScheduleItemPressed;

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
                        onExportPressed: onExportPressed,
                  onAddScheduleItemPressed: onAddScheduleItemPressed,
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
                if (controller.validationIssues.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _ScheduleValidationCard(issues: controller.validationIssues),
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
    required this.onExportPressed,
    required this.onAddScheduleItemPressed,
  });

  final ScheduleController controller;
  final VoidCallback onGeneratePressed;
  final VoidCallback onClearPressed;
  final VoidCallback onExportPressed;
  final VoidCallback onAddScheduleItemPressed;

  @override
  Widget build(BuildContext context) {
    final schedule = controller.schedule;
    final manualRepeatCount = schedule?.items
            .where((item) => item.id.startsWith('manual_repeat_'))
            .length ??
        0;
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
          const _OverviewInformationRow(
            icon: Icons.edit_calendar_outlined,
            label: '事前プラン：来園前の追加・再生成・空き時間調整はこの画面で行います。',
          ),
          const SizedBox(height: 7),
          _OverviewInformationRow(
            icon: Icons.auto_awesome_outlined,
            label: schedule == null
                ? 'スケジュールは未生成です'
                : manualRepeatCount == 0
                    ? '${schedule.items.length}件の予定を生成済み'
                    : '${schedule.items.length}件の予定を生成済み'
                        '（手動再乗車 $manualRepeatCount件）',
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
              child: OutlinedButton.icon(
                onPressed: onAddScheduleItemPressed,
                icon: const Icon(Icons.add_circle_outline, size: 19),
                label: const Text('ショー・パレードを追加'),
              ),
            ),
            const SizedBox(height: 7),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onExportPressed,
                icon: const Icon(Icons.text_snippet_outlined, size: 19),
                label: const Text('プランを文章で出力'),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.canUndo
                        ? controller.undoScheduleChange
                        : null,
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('元に戻す'),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.canRedo
                        ? controller.redoScheduleChange
                        : null,
                    icon: const Icon(Icons.redo, size: 18),
                    label: const Text('やり直す'),
                  ),
                ),
              ],
            ),
            if (controller.historyCount > 0) ...[
              const SizedBox(height: 5),
              Text(
                '履歴 ${controller.historyCount}件（最大10件）',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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

class _ScheduleValidationCard extends StatelessWidget {
  const _ScheduleValidationCard({required this.issues});

  final List<ScheduleValidationIssue> issues;

  @override
  Widget build(BuildContext context) {
    final important = issues
        .where(
          (issue) => issue.severity != ScheduleValidationSeverity.information,
        )
        .toList(growable: false);
    final displayIssues = important.isEmpty ? issues : important;
    final hasError = displayIssues.any(
      (issue) => issue.severity == ScheduleValidationSeverity.error,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasError ? Icons.error_outline : Icons.verified_outlined,
                color: hasError ? colorScheme.error : colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                hasError ? 'プラン安全確認' : 'プラン確認結果',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final issue in displayIssues)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text('・${issue.message}'),
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
            for (var index = 0; index < schedule.items.length; index++) ...[
              if (index > 0) ...[
                if (_planVisibleBufferMinutes(
                      schedule.items[index - 1],
                      schedule.items[index],
                    ) >=
                    30)
                  _PlanBufferGapCard(
                    startMinutes: _planScheduleEndMinutes(
                      schedule.items[index - 1],
                    ),
                    endMinutes: _planScheduleStartMinutes(schedule.items[index]),
                  )
                else if (_planVisibleBufferMinutes(
                          schedule.items[index - 1],
                          schedule.items[index],
                        ) >=
                        15)
                  _PlanCompactBufferGap(
                    minutes: _planVisibleBufferMinutes(
                      schedule.items[index - 1],
                      schedule.items[index],
                    ),
                  ),
              ],
              _ScheduleTimelineItem(
                item: schedule.items[index],
                facility: controller.facilityById(
                  schedule.items[index].facilityId,
                ),
                preference: controller.preferenceByFacilityId(
                  schedule.items[index].facilityId,
                ),
                controller: controller,
                isFirst: index == 0,
                isLast: index == schedule.items.length - 1,
              ),
            ],
        ],
      ),
    );
  }
}

int _planScheduleStartMinutes(ScheduleItem item) {
  return item.startHour * 60 + item.startMinute;
}

int _planScheduleEndMinutes(ScheduleItem item) {
  return item.endHour * 60 + item.endMinute;
}

int _planVisibleBufferMinutes(ScheduleItem previous, ScheduleItem next) {
  final gap =
      _planScheduleStartMinutes(next) - _planScheduleEndMinutes(previous);
  return gap > 0 ? gap : 0;
}

String _planClockLabel(int minutes) {
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _PlanCompactBufferGap extends StatelessWidget {
  const _PlanCompactBufferGap({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 80, bottom: 6),
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

class _PlanBufferGapCard extends StatelessWidget {
  const _PlanBufferGapCard({
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
                '（${_planClockLabel(startMinutes)} - ${_planClockLabel(endMinutes)}）',
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

class _ScheduleTimelineItem extends StatefulWidget {
  const _ScheduleTimelineItem({
    required this.item,
    required this.facility,
    required this.preference,
    required this.controller,
    required this.isFirst,
    required this.isLast,
  });

  final ScheduleItem item;
  final Facility? facility;
  final PlanPreference? preference;
  final ScheduleController controller;
  final bool isFirst;
  final bool isLast;

  @override
  State<_ScheduleTimelineItem> createState() {
    return _ScheduleTimelineItemState();
  }
}

class _ScheduleTimelineItemState extends State<_ScheduleTimelineItem> {
  bool _isExpanded = false;
  bool _isLoadingFreeTimeChoices = false;
  bool _isLoadingRepeatChoices = false;

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

  bool get _isFreeTime {
    return item.type.name == 'breakTime';
  }

  bool get _usesUnlimitedRide {
    final source = item.waitEstimateSource?.trim() ?? '';
    return source.startsWith('バケーションパッケージ乗り放題') ||
        source.startsWith('バケパ乗り放題');
  }

  bool get _canAddPlannedRepeat {
    return facility?.category == FacilityCategory.attraction &&
        _usesUnlimitedRide;
  }

  Future<void> _showPlannedRepeatRide() async {
    final target = facility;
    if (target == null || _isLoadingRepeatChoices) return;

    setState(() => _isLoadingRepeatChoices = true);
    final choices = await widget.controller.loadRepeatRideChoicesForFacility(
      target.id,
    );
    if (!mounted) return;
    setState(() => _isLoadingRepeatChoices = false);

    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('このアトラクションを追加できる20分以上の空き時間がありません。'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final selected = await showModalBottomSheet<FreeTimeImprovementChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.72,
          child: Scaffold(
            appBar: AppBar(
              title: Text('${target.name}をもう一度'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: '閉じる',
                ),
              ],
            ),
            body: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
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
                    '${choice.repeatNumber ?? 2}回目として手動追加・前後の予定は維持',
                  ),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => Navigator.of(sheetContext).pop(choice),
                );
              },
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;

    await widget.controller.applyFreeTimeImprovement(selected);
    if (!mounted) return;
    if (widget.controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.controller.errorMessage!)),
      );
      return;
    }

    final noticeWidth = MediaQuery.sizeOf(context).width;
    final noticeHorizontalMargin =
        noticeWidth >= 900 ? (noticeWidth - 560) / 2 : 16.0;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          noticeHorizontalMargin,
          0,
          noticeHorizontalMargin,
          noticeWidth >= 900 ? 144.0 : 96.0,
        ),
        duration: const Duration(seconds: 4),
        content: Text('${target.name}を${selected.repeatNumber ?? 2}回目として予定へ追加しました。'),
      ),
    );
  }

  Future<void> _showFreeTimeImprovement() {
    return _showFreeTimeImprovementFor(item);
  }

  Future<void> _showFreeTimeImprovementFor(ScheduleItem targetItem) async {
    if (_isLoadingFreeTimeChoices) return;
    setState(() => _isLoadingFreeTimeChoices = true);
    final choices = await widget.controller.loadFreeTimeImprovementChoices(targetItem);
    if (!mounted) return;
    setState(() => _isLoadingFreeTimeChoices = false);

    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('この空き時間に、前後の移動まで含めて安全に入る候補がありません。'),
        ),
      );
      return;
    }

    final contextInfo = _freeTimeContext(targetItem);
    final selected = await showModalBottomSheet<FreeTimeImprovementChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.90,
          child: _FreeTimeImprovementSheet(
            freeTimeItem: targetItem,
            choices: choices,
            previousTitle: contextInfo.previousTitle,
            nextTitle: contextInfo.nextTitle,
          ),
        );
      },
    );
    if (selected == null || !mounted) return;

    await widget.controller.applyFreeTimeImprovement(selected);
    if (!mounted) return;
    if (widget.controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.controller.errorMessage!)),
      );
      return;
    }

    final remaining = _largestRemainingFreeTime(targetItem);
    final action = selected.kind == FreeTimeImprovementKind.performance
        ? '公演を追加して再生成しました'
        : '${selected.plannedStartLabel}頃に、既存の予定を維持したまま空き時間へ追加しました';
    final remainingMinutes = remaining == null
        ? 0
        : _scheduleItemDurationMinutes(remaining);
    final noticeWidth = MediaQuery.sizeOf(context).width;
    final noticeHorizontalMargin =
        noticeWidth >= 900 ? (noticeWidth - 560) / 2 : 16.0;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          noticeHorizontalMargin,
          0,
          noticeHorizontalMargin,
          noticeWidth >= 900 ? 144.0 : 96.0,
        ),
        duration: const Duration(seconds: 4),
        content: Text('${selected.facility.name}を$action。'),
        action: remaining == null || remainingMinutes < 20
            ? null
            : SnackBarAction(
                label: '残り$remainingMinutes分を改善',
                onPressed: () {
                  if (!mounted) return;
                  _showFreeTimeImprovementFor(remaining);
                },
              ),
      ),
    );
  }

  ({String? previousTitle, String? nextTitle}) _freeTimeContext(
    ScheduleItem targetItem,
  ) {
    final currentSchedule = widget.controller.schedule;
    if (currentSchedule == null) {
      return (previousTitle: null, nextTitle: null);
    }
    final sorted = [...currentSchedule.items]
      ..sort((a, b) {
        final aStart = a.startHour * 60 + a.startMinute;
        final bStart = b.startHour * 60 + b.startMinute;
        return aStart.compareTo(bStart);
      });
    final index = sorted.indexWhere((candidate) => candidate.id == targetItem.id);
    if (index < 0) {
      return (previousTitle: null, nextTitle: null);
    }
    return (
      previousTitle: index > 0 ? sorted[index - 1].title : null,
      nextTitle: index + 1 < sorted.length ? sorted[index + 1].title : null,
    );
  }

  ScheduleItem? _largestRemainingFreeTime(ScheduleItem originalGap) {
    final currentSchedule = widget.controller.schedule;
    if (currentSchedule == null) return null;
    final originalStart = originalGap.startHour * 60 + originalGap.startMinute;
    final originalEnd = originalGap.endHour * 60 + originalGap.endMinute;
    final candidates = currentSchedule.items.where((candidate) {
      if (candidate.type.name != 'breakTime') return false;
      final start = candidate.startHour * 60 + candidate.startMinute;
      final end = candidate.endHour * 60 + candidate.endMinute;
      return start >= originalStart && end <= originalEnd && end - start >= 20;
    }).toList(growable: false);
    if (candidates.isEmpty) return null;
    candidates.sort(
      (left, right) => _scheduleItemDurationMinutes(right)
          .compareTo(_scheduleItemDurationMinutes(left)),
    );
    return candidates.first;
  }

  int _scheduleItemDurationMinutes(ScheduleItem targetItem) {
    final start = targetItem.startHour * 60 + targetItem.startMinute;
    final end = targetItem.endHour * 60 + targetItem.endMinute;
    return end - start;
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
                        if (item.id.startsWith('manual_repeat_'))
                          IconButton(
                            tooltip: 'この再乗車だけ削除',
                            onPressed: () {
                              final removed = widget.controller.removeManualRepeat(
                                item.id,
                              );
                              if (!removed || !mounted) return;
                              final noticeWidth =
                                  MediaQuery.sizeOf(context).width;
                              final noticeHorizontalMargin =
                                  noticeWidth >= 900
                                      ? (noticeWidth - 560) / 2
                                      : 16.0;
                              final messenger =
                                  ScaffoldMessenger.of(context);
                              messenger.hideCurrentSnackBar();
                              messenger.showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  margin: EdgeInsets.fromLTRB(
                                    noticeHorizontalMargin,
                                    0,
                                    noticeHorizontalMargin,
                                    noticeWidth >= 900 ? 144.0 : 96.0,
                                  ),
                                  duration: const Duration(seconds: 4),
                                  content: Text(
                                    '${item.title}を削除し、空き時間に戻しました。',
                                  ),
                                  action: SnackBarAction(
                                    label: '元に戻す',
                                    onPressed:
                                        widget.controller.undoScheduleChange,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.delete_outline),
                          )
                        else if (facility != null)
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
                          if (item.id.startsWith('manual_repeat_'))
                            const _PreferenceBadge(
                              icon: Icons.repeat,
                              label: 'バケパ乗り放題・手動再乗車',
                              foregroundColor: Color(0xFF4F378B),
                              backgroundColor: Color(0xFFF1ECFF),
                              borderColor: Color(0xFFC8B8F8),
                            ),
                        ],
                      ),
                    ],
                    if (_canAddPlannedRepeat) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLoadingRepeatChoices
                              ? null
                              : _showPlannedRepeatRide,
                          icon: _isLoadingRepeatChoices
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.repeat),
                          label: Text(
                            _isLoadingRepeatChoices
                                ? '空き時間を確認中...'
                                : 'もう一度乗る予定を追加',
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '事前計画として追加します。Plannerが自動で2回目を入れることはありません。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
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
                    if (_isFreeTime) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: _isLoadingFreeTimeChoices
                              ? null
                              : _showFreeTimeImprovement,
                          icon: _isLoadingFreeTimeChoices
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_fix_high_outlined),
                          label: Text(
                            _isLoadingFreeTimeChoices
                                ? '候補を計算中...'
                                : 'この空き時間を改善',
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '前後の移動と待ち時間を含め、この枠に収まる候補だけを表示します。自動では追加しません。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
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
                      if (_isExpanded) ...[
                        const SizedBox(height: 2),
                        _ScheduleItemDetails(item: item),
                      ],
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

    if (preference.fixedTimeStatus == FixedTimeStatus.confirmed) {
      badges.add(
        const _PreferenceBadge(
          icon: Icons.lock_outline,
          label: '固定予定',
          foregroundColor: Color(0xFF8A4B08),
          backgroundColor: Color(0xFFFFF3E0),
          borderColor: Color(0xFFFFCC80),
        ),
      );
    }

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

    if (preference.fixedTimeStatus == FixedTimeStatus.planned &&
        preference.scheduledAccessTime.trim().isNotEmpty) {
      badges.add(
        _PreferenceBadge(
          icon: Icons.auto_fix_high_outlined,
          label: '${preference.scheduledAccessTime} 空き時間で追加',
          foregroundColor: const Color(0xFF4F378B),
          backgroundColor: const Color(0xFFF1ECFF),
          borderColor: const Color(0xFFC8B8F8),
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
              title: 'AI配置理由',
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
              title: '施設メモ',
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


class _FreeTimeImprovementSheet extends StatefulWidget {
  const _FreeTimeImprovementSheet({
    required this.freeTimeItem,
    required this.choices,
    required this.previousTitle,
    required this.nextTitle,
  });

  final ScheduleItem freeTimeItem;
  final List<FreeTimeImprovementChoice> choices;
  final String? previousTitle;
  final String? nextTitle;

  @override
  State<_FreeTimeImprovementSheet> createState() =>
      _FreeTimeImprovementSheetState();
}

class _FreeTimeImprovementSheetState extends State<_FreeTimeImprovementSheet> {
  bool _showAllNewRecommendations = false;

  int get _gapMinutes {
    final start = widget.freeTimeItem.startHour * 60 +
        widget.freeTimeItem.startMinute;
    final end = widget.freeTimeItem.endHour * 60 + widget.freeTimeItem.endMinute;
    return end - start;
  }

  List<FreeTimeImprovementChoice> _sorted(
    Iterable<FreeTimeImprovementChoice> source,
  ) {
    final values = source.toList(growable: false);
    values.sort((left, right) {
      final scoreCompare = right.score.compareTo(left.score);
      if (scoreCompare != 0) return scoreCompare;
      return left.plannedStartMinutes.compareTo(right.plannedStartMinutes);
    });
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final wishlisted = _sorted(
      widget.choices.where(
        (choice) =>
            choice.kind == FreeTimeImprovementKind.facility &&
            choice.alreadySelected,
      ),
    );
    final repeats = _sorted(
      widget.choices.where(
        (choice) => choice.kind == FreeTimeImprovementKind.repeatAttraction,
      ),
    );
    final performances = _sorted(
      widget.choices.where(
        (choice) => choice.kind == FreeTimeImprovementKind.performance,
      ),
    );
    final newRecommendations = _sorted(
      widget.choices.where(
        (choice) =>
            choice.kind == FreeTimeImprovementKind.facility &&
            !choice.alreadySelected,
      ),
    );

    final visibleNewRecommendations = _showAllNewRecommendations
        ? newRecommendations
        : newRecommendations.take(3).toList(growable: false);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.freeTimeItem.startTimeLabel}〜${widget.freeTimeItem.endTimeLabel}を改善',
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: '閉じる',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '空き時間 $_gapMinutes分',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                if (widget.previousTitle != null)
                  Text('前の予定：${widget.previousTitle}'),
                if (widget.nextTitle != null)
                  Text('次の予定：${widget.nextTitle}'),
                const SizedBox(height: 8),
                const Text(
                  'まず「やりたいこと」に登録済みの未実施施設を優先します。'
                  'ショー・パレードと未登録施設は別枠で表示し、'
                  '未登録候補が登録済み施設を押しのけないようにしています。'
                  '候補は自動追加されません。',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Text(
            'やりたいことからおすすめ',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '登録済みで、まだ予定に入っていない施設を最優先で表示します。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 7),
          if (wishlisted.isEmpty)
            _FreeTimeEmptySection(
              icon: Icons.favorite_border,
              message: 'この空き時間に安全に入る未実施の「やりたいこと」はありません。',
            )
          else
            for (var index = 0; index < wishlisted.length; index++)
              _FreeTimeImprovementChoiceTile(
                choice: wishlisted[index],
                rank: index + 1,
                emphasized: index == 0,
              ),

          if (repeats.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'もう一度乗る（乗り放題）',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'すでに予定に入っている乗り放題対象アトラクションです。'
              'Disney Plannerは自動では追加しません。'
              'もう一度乗りたい施設だけ、ユーザーが選んで追加できます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 7),
            for (var index = 0; index < repeats.length; index++)
              _FreeTimeImprovementChoiceTile(
                choice: repeats[index],
                rank: index + 1,
              ),
          ],

          if (performances.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'ショー・パレード',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'この時間枠に収まる公演です。エントリー受付やDPA対象公演は、'
              '当選・購入済みの場合だけ追加してください。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 7),
            for (var index = 0; index < performances.length; index++)
              _FreeTimeImprovementChoiceTile(
                choice: performances[index],
                rank: index + 1,
              ),
          ],

          if (newRecommendations.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              '新しいおすすめ',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '「やりたいこと」には未登録の候補です。'
              'マスタ上の人気度は参考程度にとどめ、体験価値・待ち時間・移動・空き時間の有効活用を総合評価します。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 7),
            for (var index = 0;
                index < visibleNewRecommendations.length;
                index++)
              _FreeTimeImprovementChoiceTile(
                choice: visibleNewRecommendations[index],
                rank: index + 1,
                emphasized: wishlisted.isEmpty &&
                    repeats.isEmpty &&
                    performances.isEmpty &&
                    index == 0,
              ),
            if (newRecommendations.length > 3) ...[
              const SizedBox(height: 2),
              OutlinedButton.icon(
                onPressed: () => setState(
                  () => _showAllNewRecommendations =
                      !_showAllNewRecommendations,
                ),
                icon: Icon(
                  _showAllNewRecommendations
                      ? Icons.expand_less
                      : Icons.expand_more,
                ),
                label: Text(
                  _showAllNewRecommendations
                      ? '新しいおすすめを閉じる'
                      : 'その他の新しいおすすめを表示（${newRecommendations.length - 3}件）',
                ),
              ),
            ],
          ],

          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '乗り放題対象の再乗車は「もう一度乗る」から手動で追加できます。'
              'Disney Plannerが勝手に2回目・3回目を追加することはありません。'
              '1件追加したあとも空き時間が20分以上残れば、残り時間を続けて改善できます。',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.free_breakfast_outlined),
            label: const Text('このまま休憩・自由時間にする'),
          ),
        ],
      ),
    );
  }
}

class _FreeTimeEmptySection extends StatelessWidget {
  const _FreeTimeEmptySection({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeTimeImprovementChoiceTile extends StatelessWidget {
  const _FreeTimeImprovementChoiceTile({
    required this.choice,
    required this.rank,
    this.emphasized = false,
  });

  final FreeTimeImprovementChoice choice;
  final int rank;
  final bool emphasized;

  String _recommendationReason() {
    final totalMovement = choice.movementInMinutes + choice.movementOutMinutes;
    final wait = choice.estimatedWaitMinutes;
    if (choice.kind == FreeTimeImprovementKind.repeatAttraction) {
      final repeatNumber = choice.repeatNumber ?? 2;
      return 'すでに予定にある乗り放題対象です。選んだ場合だけ$repeatNumber回目として手動追加します。';
    }
    if (choice.alreadySelected) {
      return 'やりたいことに登録済みで、この空き時間に安全に収まります。';
    }
    if (choice.kind == FreeTimeImprovementKind.performance) {
      return 'この時間枠で鑑賞でき、前後の予定にも間に合う公演です。';
    }
    if (choice.facility.category == FacilityCategory.greeting) {
      return '未登録のグリーティング候補です。カテゴリだけでは優先せず、体験価値・待ち時間・移動・空き枠活用を総合評価しています。';
    }
    if (!choice.alreadySelected && choice.expertScore >= 75) {
      return '体験価値が高く、空き時間を有効に使える新しいおすすめです。';
    }
    if (choice.fitSlackMinutes <= 30) {
      return '前後の予定を守りながら、空き時間を無駄なく使える候補です。';
    }
    if (totalMovement <= 10) {
      return '前後の移動が少なく、空き時間を効率よく使える候補です。';
    }
    if (wait != null && wait <= 15) {
      return '待ち時間は短めですが、短さだけでなく体験価値と空き枠活用も含めて評価しています。';
    }
    return '体験価値・待ち時間・前後の移動・空き枠の使い切りやすさを総合評価した候補です。';
  }

  @override
  Widget build(BuildContext context) {
    final isPerformance = choice.kind == FreeTimeImprovementKind.performance;
    final isRepeat =
        choice.kind == FreeTimeImprovementKind.repeatAttraction;
    final wait = choice.estimatedWaitMinutes;
    final colorScheme = Theme.of(context).colorScheme;
    final kindLabel = isRepeat
        ? 'もう一度乗る'
        : isPerformance
            ? choice.facility.category == FacilityCategory.parade
                ? 'パレード'
                : 'ショー'
            : choice.facility.category == FacilityCategory.greeting
                ? 'グリーティング'
                : 'アトラクション';

    return Card(
      margin: const EdgeInsets.only(bottom: 7),
      color: emphasized ? colorScheme.primaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).pop(choice),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                child: Icon(
                  isPerformance
                      ? choice.facility.category == FacilityCategory.parade
                          ? Icons.celebration_outlined
                          : Icons.theater_comedy_outlined
                      : choice.facility.category == FacilityCategory.greeting
                          ? Icons.people_alt_outlined
                          : Icons.attractions_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '$rank位',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            kindLabel,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        if (choice.alreadySelected && !isRepeat)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'やりたいこと',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        if (isRepeat)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${choice.repeatNumber ?? 2}回目として追加',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      choice.facility.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isPerformance
                          ? '${choice.plannedStartLabel}開演・約${choice.facility.durationMinutes}分・${choice.preparationMinutes}分前準備'
                          : '${choice.plannedStartLabel}〜${choice.plannedEndLabel}${wait == null ? '' : '・予測待ち約$wait分'}',
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '前から${choice.movementInMinutes}分 ／ 次へ${choice.movementOutMinutes}分'
                      '${choice.fitSlackMinutes > 0 ? ' ／ 追加後の余白 約${choice.fitSlackMinutes}分' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _recommendationReason(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: emphasized
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                    ),
                    if (!isPerformance && choice.expertScore > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Disney通おすすめ評価 ${choice.expertScore.toStringAsFixed(1)}点'
                        '${choice.expertReason == null || choice.expertReason!.trim().isEmpty ? '' : '（${choice.expertReason}）'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    if (!isPerformance && choice.waitSource != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        choice.waitSource!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPerformanceSheet extends StatelessWidget {
  const _AddPerformanceSheet({
    required this.choices,
    required this.schedule,
  });

  final List<PerformancePlanChoice> choices;
  final DaySchedule schedule;

  bool _hasExactPerformance(PerformancePlanChoice choice) {
    return schedule.items.any((item) {
      return item.facilityId == choice.facility.id &&
          item.startTimeLabel == choice.option.startTime;
    });
  }

  bool _hasOverlap(PerformancePlanChoice choice) {
    final startParts = choice.option.startTime.split(':');
    if (startParts.length != 2) return false;
    final start =
        (int.tryParse(startParts[0]) ?? 0) * 60 +
        (int.tryParse(startParts[1]) ?? 0);
    final end = start + choice.facility.durationMinutes;

    return schedule.items.any((item) {
      if (item.type.name == 'entry' || item.type.name == 'exit') {
        return false;
      }
      final itemStart = item.startHour * 60 + item.startMinute;
      final itemEnd = item.endHour * 60 + item.endMinute;
      return start < itemEnd && end > itemStart;
    });
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
                '当選・購入したショーやパレードを選ぶと、その公演時刻を固定してプラン全体を再生成します。',
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
                    '${overlaps && !alreadyAdded ? '　現在の予定と重なります（追加後に再調整）' : ''}',
                  ),
                  trailing: alreadyAdded
                      ? const Chip(label: Text('追加済み'))
                      : const Icon(Icons.add),
                  enabled: !alreadyAdded,
                  onTap: alreadyAdded
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

class _PlanTextExportDialog extends StatefulWidget {
  const _PlanTextExportDialog({
    required this.simpleText,
    required this.evaluationText,
  });

  final String simpleText;
  final String evaluationText;

  @override
  State<_PlanTextExportDialog> createState() => _PlanTextExportDialogState();
}

class _PlanTextExportDialogState extends State<_PlanTextExportDialog> {
  final ScrollController _scrollController = ScrollController();
  PlanTextExportFormat _format = PlanTextExportFormat.simple;

  String get _text => switch (_format) {
    PlanTextExportFormat.simple => widget.simpleText,
    PlanTextExportFormat.evaluation => widget.evaluationText,
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _text));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('プラン文章をコピーしました。')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return AlertDialog(
      title: const Text('プランを文章で出力'),
      content: SizedBox(
        width: size.width < 700 ? size.width : 680,
        height: size.height * 0.65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<PlanTextExportFormat>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: PlanTextExportFormat.simple,
                  icon: Icon(Icons.short_text),
                  label: Text('簡易版'),
                ),
                ButtonSegment(
                  value: PlanTextExportFormat.evaluation,
                  icon: Icon(Icons.analytics_outlined),
                  label: Text('AI評価用'),
                ),
              ],
              selected: {_format},
              onSelectionChanged: (values) {
                setState(() => _format = values.first);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  interactive: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: SelectableText(
                      _text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
        FilledButton.icon(
          onPressed: _copy,
          icon: const Icon(Icons.copy),
          label: const Text('コピー'),
        ),
      ],
    );
  }
}
