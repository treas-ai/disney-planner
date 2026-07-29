import 'package:flutter/material.dart';

class AppInfoRow extends StatelessWidget {
  const AppInfoRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.child,
    this.showDivider = false,
    this.compact = false,
  }) : assert(value != null || child != null, 'valueまたはchildを指定してください。');

  final IconData icon;
  final String label;
  final String? value;
  final Widget? child;
  final bool showDivider;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 5 : 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: compact ? 16 : 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              SizedBox(
                width: compact ? 76 : 92,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child:
                    child ??
                    Text(
                      value!,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
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
