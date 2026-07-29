import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

enum AppMessageType { info, success, warning, error }

class AppWarningCard extends StatelessWidget {
  const AppWarningCard({
    super.key,
    required this.title,
    required this.message,
    this.type = AppMessageType.warning,
    this.action,
    this.onClose,
  });

  final String title;
  final String message;
  final AppMessageType type;
  final Widget? action;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle(type);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: style.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(style.icon, size: 21, color: style.foreground),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: style.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: style.foreground,
                    height: 1.4,
                  ),
                ),
                if (action != null) ...[const SizedBox(height: 7), action!],
              ],
            ),
          ),
          if (onClose != null)
            IconButton(
              tooltip: '閉じる',
              onPressed: onClose,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close, size: 18, color: style.foreground),
            ),
        ],
      ),
    );
  }

  _MessageStyle _resolveStyle(AppMessageType value) {
    return switch (value) {
      AppMessageType.info => const _MessageStyle(
        icon: Icons.info_outline,
        foreground: AppColors.info,
        background: Color(0xFFEAF2FF),
        border: Color(0xFFA9C5F2),
      ),
      AppMessageType.success => const _MessageStyle(
        icon: Icons.check_circle_outline,
        foreground: AppColors.success,
        background: Color(0xFFE8F5ED),
        border: Color(0xFFA5D6B8),
      ),
      AppMessageType.warning => const _MessageStyle(
        icon: Icons.warning_amber_outlined,
        foreground: AppColors.warning,
        background: Color(0xFFFFF8DF),
        border: Color(0xFFE6CE81),
      ),
      AppMessageType.error => const _MessageStyle(
        icon: Icons.error_outline,
        foreground: AppColors.error,
        background: Color(0xFFFFEBEE),
        border: Color(0xFFEF9A9A),
      ),
    };
  }
}

class _MessageStyle {
  const _MessageStyle({
    required this.icon,
    required this.foreground,
    required this.background,
    required this.border,
  });

  final IconData icon;
  final Color foreground;
  final Color background;
  final Color border;
}
