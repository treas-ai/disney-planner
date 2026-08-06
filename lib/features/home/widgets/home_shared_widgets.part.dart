part of '../home_screen.dart';

class _HomeCardHeader extends StatelessWidget {
  const _HomeCardHeader({
    required this.title,
    required this.icon,
    this.trailing,
    this.actionLabel,
    this.actionIcon,
    this.onActionPressed,
  });

  final String title;
  final IconData icon;
  final String? trailing;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 21),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null) ...[
          Text(
            trailing!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (actionLabel != null) const SizedBox(width: 5),
        ],
        if (actionLabel != null)
          OutlinedButton.icon(
            onPressed: onActionPressed,
            icon: Icon(actionIcon ?? Icons.arrow_forward, size: 16),
            label: Text(actionLabel!),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            ),
          ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.title,
    required this.value,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              SizedBox(
                width: 86,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: colorScheme.outlineVariant),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        '$label $count',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
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
