part of '../home_screen.dart';

class _ScheduleSummaryCard extends StatelessWidget {
  const _ScheduleSummaryCard({
    required this.settings,
    required this.schedule,
    required this.onReviewPlanPressed,
    required this.onTodayPlanPressed,
  });

  final TripSettings settings;
  final DaySchedule? schedule;
  final VoidCallback onReviewPlanPressed;
  final VoidCallback onTodayPlanPressed;

  @override
  Widget build(BuildContext context) {
    final scheduleMatchesPark =
        schedule != null && schedule!.parkId == settings.parkId;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeCardHeader(
            title: '生成済みプラン',
            icon: Icons.route_outlined,
            trailing: scheduleMatchesPark ? '${schedule!.items.length}件' : null,
            actionLabel: scheduleMatchesPark ? '当日を見る' : '確認する',
            actionIcon: scheduleMatchesPark
                ? Icons.event_available_outlined
                : Icons.visibility_outlined,
            onActionPressed: scheduleMatchesPark
                ? onTodayPlanPressed
                : onReviewPlanPressed,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (schedule == null)
            const _ScheduleEmptyMessage(
              icon: Icons.auto_awesome_outlined,
              title: 'プラン未生成',
              message: '候補確認まで進むと、AIが一日の予定を組み立てます。',
            )
          else if (!scheduleMatchesPark)
            const _ScheduleEmptyMessage(
              icon: Icons.sync_problem_outlined,
              title: '別のパークのプランです',
              message: '現在選択しているパークでプランを再生成してください。',
            )
          else if (schedule!.items.isEmpty)
            const _ScheduleEmptyMessage(
              icon: Icons.event_busy_outlined,
              title: '予定がありません',
              message: '条件や施設を見直して再生成してください。',
            )
          else ...[
            _ScheduleOverview(schedule: schedule!),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '最初の予定',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            _FirstScheduleItem(item: schedule!.items.first),
            if (schedule!.items.length > 1) ...[
              const SizedBox(height: 8),
              Text(
                'ほか${schedule!.items.length - 1}件の予定があります。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: scheduleMatchesPark
                ? FilledButton.icon(
                    onPressed: onTodayPlanPressed,
                    icon: const Icon(Icons.event_available_outlined, size: 19),
                    label: const Text('当日の予定を確認'),
                  )
                : OutlinedButton.icon(
                    onPressed: onReviewPlanPressed,
                    icon: const Icon(Icons.route_outlined, size: 19),
                    label: const Text('プラン確認へ'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleOverview extends StatelessWidget {
  const _ScheduleOverview({required this.schedule});

  final DaySchedule schedule;

  @override
  Widget build(BuildContext context) {
    final firstItem = schedule.items.first;
    final lastItem = schedule.items.last;

    return Row(
      children: [
        Expanded(
          child: _ScheduleMetric(
            label: '開始',
            value: firstItem.startTimeLabel,
            icon: Icons.play_arrow_outlined,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _ScheduleMetric(
            label: '終了',
            value: lastItem.endTimeLabel,
            icon: Icons.stop_outlined,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _ScheduleMetric(
            label: '予定',
            value: '${schedule.items.length}件',
            icon: Icons.event_note_outlined,
          ),
        ),
      ],
    );
  }
}

class _ScheduleMetric extends StatelessWidget {
  const _ScheduleMetric({
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 17, color: colorScheme.primary),
          const SizedBox(height: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _FirstScheduleItem extends StatelessWidget {
  const _FirstScheduleItem({required this.item});

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              item.startTimeLabel,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  item.type.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleEmptyMessage extends StatelessWidget {
  const _ScheduleEmptyMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 7),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

