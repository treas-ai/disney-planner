part of '../home_screen.dart';

class _HomeProgressCard extends StatelessWidget {
  const _HomeProgressCard({
    required this.action,
    required this.selectedWishCount,
    required this.selectedFacilityCount,
    required this.hasCurrentSchedule,
  });

  final _HomeAction action;
  final int selectedWishCount;
  final int selectedFacilityCount;
  final bool hasCurrentSchedule;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final completedSteps = 1 +
        (selectedWishCount > 0 ? 1 : 0) +
        (selectedFacilityCount > 0 ? 1 : 0) +
        (hasCurrentSchedule ? 2 : 0);
    final progress = completedSteps / 5;

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
                  color: action.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.auto_awesome_outlined,
                  size: 22,
                  color: action.foregroundColor,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AIからのご案内',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      action.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                '準備の進み具合',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$completedSteps / 5 ステップ',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              const _ProgressBadge(label: '旅行設定', completed: true),
              _ProgressBadge(
                label: 'やりたいこと',
                completed: selectedWishCount > 0,
              ),
              _ProgressBadge(
                label: '候補確認',
                completed: selectedFacilityCount > 0,
              ),
              _ProgressBadge(
                label: 'プラン',
                completed: hasCurrentSchedule,
              ),
              _ProgressBadge(
                label: '当日',
                completed: hasCurrentSchedule,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.south_outlined,
                size: 17,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '画面下の「${action.buttonLabel}」から次へ進めます。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({required this.label, required this.completed});

  final String label;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: completed
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: completed ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.circle_outlined,
            size: 15,
            color: completed ? colorScheme.primary : colorScheme.outline,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: completed
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeAction {
  const _HomeAction({
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
}

