import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/state/app_state.dart';
import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/entities/day_schedule.dart';
import '../../domain/entities/schedule_item.dart';

class TodayPlanScreen extends StatefulWidget {
  const TodayPlanScreen({super.key});

  @override
  State<TodayPlanScreen> createState() {
    return _TodayPlanScreenState();
  }
}

class _TodayPlanScreenState extends State<TodayPlanScreen> {
  AppState? _appState;

  late final ScrollController _mobileScrollController;
  late final ScrollController _scheduleScrollController;

  Timer? _clockTimer;

  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();

    _mobileScrollController = ScrollController();
    _scheduleScrollController = ScrollController();

    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final appState = AppStateScope.of(context);

    if (identical(_appState, appState)) {
      return;
    }

    _appState?.removeListener(_refresh);
    _appState = appState;
    _appState!.addListener(_refresh);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();

    _appState?.removeListener(_refresh);

    _mobileScrollController.dispose();
    _scheduleScrollController.dispose();

    super.dispose();
  }

  void _refresh() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _refreshCurrentTime() {
    setState(() {
      _now = DateTime.now();
    });
  }

  Future<void> _scrollToCurrentSchedule() async {
    final schedule = _appState?.daySchedule;

    if (schedule == null || schedule.items.isEmpty) {
      return;
    }

    final currentIndex = _currentOrNextIndex(schedule.items, _now);

    if (currentIndex == null) {
      return;
    }

    final useDesktopLayout = MediaQuery.sizeOf(context).width >= 900;

    final controller = useDesktopLayout
        ? _scheduleScrollController
        : _mobileScrollController;

    if (!controller.hasClients) {
      return;
    }

    const estimatedItemHeight = 150.0;

    final targetOffset = currentIndex * estimatedItemHeight;

    final maxOffset = controller.position.maxScrollExtent;

    await controller.animateTo(
      targetOffset.clamp(0, maxOffset),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = _appState;

    if (appState == null) {
      return const AppScaffold(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final schedule = appState.daySchedule;

    return AppScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useTwoColumns = constraints.maxWidth >= 900;

          if (useTwoColumns) {
            return _DesktopTodayLayout(
              schedule: schedule,
              currentParkId: appState.tripSettings.parkId,
              now: _now,
              scheduleScrollController: _scheduleScrollController,
              onRefreshPressed: _refreshCurrentTime,
              onCurrentSchedulePressed: _scrollToCurrentSchedule,
            );
          }

          return _MobileTodayLayout(
            schedule: schedule,
            currentParkId: appState.tripSettings.parkId,
            now: _now,
            scrollController: _mobileScrollController,
            onRefreshPressed: _refreshCurrentTime,
            onCurrentSchedulePressed: _scrollToCurrentSchedule,
          );
        },
      ),
    );
  }
}

class _MobileTodayLayout extends StatelessWidget {
  const _MobileTodayLayout({
    required this.schedule,
    required this.currentParkId,
    required this.now,
    required this.scrollController,
    required this.onRefreshPressed,
    required this.onCurrentSchedulePressed,
  });

  final DaySchedule? schedule;
  final String currentParkId;
  final DateTime now;
  final ScrollController scrollController;
  final VoidCallback onRefreshPressed;
  final VoidCallback onCurrentSchedulePressed;

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
          _TodayOverviewCard(
            schedule: schedule,
            currentParkId: currentParkId,
            now: now,
            onRefreshPressed: onRefreshPressed,
            onCurrentSchedulePressed: onCurrentSchedulePressed,
          ),
          const SizedBox(height: AppSpacing.sm),
          _TodayScheduleContent(
            schedule: schedule,
            currentParkId: currentParkId,
            now: now,
          ),
        ],
      ),
    );
  }
}

class _DesktopTodayLayout extends StatelessWidget {
  const _DesktopTodayLayout({
    required this.schedule,
    required this.currentParkId,
    required this.now,
    required this.scheduleScrollController,
    required this.onRefreshPressed,
    required this.onCurrentSchedulePressed,
  });

  final DaySchedule? schedule;
  final String currentParkId;
  final DateTime now;
  final ScrollController scheduleScrollController;
  final VoidCallback onRefreshPressed;
  final VoidCallback onCurrentSchedulePressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 340,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: AppSpacing.sm, bottom: 48),
            child: _TodayOverviewCard(
              schedule: schedule,
              currentParkId: currentParkId,
              now: now,
              onRefreshPressed: onRefreshPressed,
              onCurrentSchedulePressed: onCurrentSchedulePressed,
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
                  schedule: schedule,
                  currentParkId: currentParkId,
                  now: now,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TodayOverviewCard extends StatelessWidget {
  const _TodayOverviewCard({
    required this.schedule,
    required this.currentParkId,
    required this.now,
    required this.onRefreshPressed,
    required this.onCurrentSchedulePressed,
  });

  final DaySchedule? schedule;
  final String currentParkId;
  final DateTime now;
  final VoidCallback onRefreshPressed;
  final VoidCallback onCurrentSchedulePressed;

  @override
  Widget build(BuildContext context) {
    final scheduleMatchesPark =
        schedule == null || schedule!.parkId == currentParkId;

    final currentItem = schedule == null
        ? null
        : _findCurrentItem(schedule!.items, now);

    final nextItem = schedule == null
        ? null
        : _findNextItem(schedule!.items, now);

    final displayItem = currentItem ?? nextItem;

    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _parkIcon(currentParkId),
                  size: 22,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _parkName(currentParkId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _formatCurrentDate(now),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '現在時刻を更新',
                onPressed: onRefreshPressed,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _CurrentTimePanel(now: now),
          if (schedule != null && !scheduleMatchesPark) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.sync_problem_outlined,
                    size: 19,
                    color: colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '表示中のプランは別のパークで生成されています。'
                      'プラン確認画面で再生成してください。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (schedule != null &&
              scheduleMatchesPark &&
              displayItem != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _CurrentOrNextScheduleCard(
              item: displayItem,
              isCurrent: identical(displayItem, currentItem),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCurrentSchedulePressed,
                icon: const Icon(Icons.my_location_outlined, size: 18),
                label: const Text('現在の予定へ移動'),
              ),
            ),
          ],
          if (schedule != null && scheduleMatchesPark) ...[
            const SizedBox(height: AppSpacing.md),
            _TodayProgressSummary(items: schedule!.items, now: now),
          ],
        ],
      ),
    );
  }

  static String _formatCurrentDate(DateTime value) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];

    return '${value.year}年'
        '${value.month}月'
        '${value.day}日'
        '（${weekdays[value.weekday - 1]}）';
  }
}

class _CurrentTimePanel extends StatelessWidget {
  const _CurrentTimePanel({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final hour = now.hour.toString().padLeft(2, '0');

    final minute = now.minute.toString().padLeft(2, '0');

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
            '$hour:$minute',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CurrentOrNextScheduleCard extends StatelessWidget {
  const _CurrentOrNextScheduleCard({
    required this.item,
    required this.isCurrent,
  });

  final ScheduleItem item;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: isCurrent
            ? colorScheme.primaryContainer
            : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCurrent ? Icons.play_circle_outline : Icons.upcoming_outlined,
                size: 18,
                color: isCurrent
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 6),
              Text(
                isCurrent ? '現在の予定' : '次の予定',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isCurrent
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: isCurrent
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.timeRangeLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isCurrent
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayProgressSummary extends StatelessWidget {
  const _TodayProgressSummary({required this.items, required this.now});

  final List<ScheduleItem> items;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final completedCount = items
        .where(
          (item) =>
              _scheduleStatus(item, now) == _TodayScheduleStatus.completed,
        )
        .length;

    final progress = items.isEmpty ? 0.0 : completedCount / items.length;

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
              '$completedCount / ${items.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 7),
        LinearProgressIndicator(
          value: progress,
          minHeight: 7,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

class _TodayScheduleContent extends StatelessWidget {
  const _TodayScheduleContent({
    required this.schedule,
    required this.currentParkId,
    required this.now,
  });

  final DaySchedule? schedule;
  final String currentParkId;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (schedule == null) {
      return const EmptyState(
        title: '当日のプランがありません',
        message: 'プラン確認画面でスケジュールを生成してください。',
        icon: Icons.event_note_outlined,
      );
    }

    if (schedule!.parkId != currentParkId) {
      return const EmptyState(
        title: 'パークが一致していません',
        message: '現在選択しているパークでプランを再生成してください。',
        icon: Icons.sync_problem_outlined,
      );
    }

    if (schedule!.items.isEmpty) {
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
                '${schedule!.items.length}件',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < schedule!.items.length; index++)
            _TodayScheduleItemCard(
              key: ValueKey('today_${schedule!.items[index].id}'),
              item: schedule!.items[index],
              now: now,
              isLast: index == schedule!.items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TodayScheduleItemCard extends StatefulWidget {
  const _TodayScheduleItemCard({
    super.key,
    required this.item,
    required this.now,
    required this.isLast,
  });

  final ScheduleItem item;
  final DateTime now;
  final bool isLast;

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
                      Text(
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
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
      'meal' => const _TodayTypeStyle(
        icon: Icons.restaurant_outlined,
        foregroundColor: Color(0xFF287A4B),
        backgroundColor: Color(0xFFE8F5ED),
      ),
      'breakTime' => const _TodayTypeStyle(
        icon: Icons.chair_outlined,
        foregroundColor: Color(0xFF7A5B16),
        backgroundColor: Color(0xFFFFF8DF),
      ),
      'move' => const _TodayTypeStyle(
        icon: Icons.directions_walk_outlined,
        foregroundColor: Color(0xFF6A3DA1),
        backgroundColor: Color(0xFFF2EAFE),
      ),
      _ => const _TodayTypeStyle(
        icon: Icons.event_outlined,
        foregroundColor: Color(0xFF514F66),
        backgroundColor: Color(0xFFF7F5FC),
      ),
    };
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

ScheduleItem? _findCurrentItem(List<ScheduleItem> items, DateTime now) {
  for (final item in items) {
    if (_scheduleStatus(item, now) == _TodayScheduleStatus.current) {
      return item;
    }
  }

  return null;
}

ScheduleItem? _findNextItem(List<ScheduleItem> items, DateTime now) {
  for (final item in items) {
    if (_scheduleStatus(item, now) == _TodayScheduleStatus.upcoming) {
      return item;
    }
  }

  return null;
}

int? _currentOrNextIndex(List<ScheduleItem> items, DateTime now) {
  for (var index = 0; index < items.length; index++) {
    final status = _scheduleStatus(items[index], now);

    if (status == _TodayScheduleStatus.current ||
        status == _TodayScheduleStatus.upcoming) {
      return index;
    }
  }

  if (items.isNotEmpty) {
    return items.length - 1;
  }

  return null;
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
