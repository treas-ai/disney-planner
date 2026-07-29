import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_badge.dart';

enum AppStatusType { neutral, info, success, warning, error }

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    required this.type,
    this.icon,
    this.compact = true,
  });

  final String label;
  final AppStatusType type;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(type);

    return AppBadge(
      label: label,
      icon: icon ?? style.icon,
      foregroundColor: style.foreground,
      backgroundColor: style.background,
      borderColor: style.border,
      compact: compact,
    );
  }

  _StatusStyle _styleFor(AppStatusType status) {
    return switch (status) {
      AppStatusType.neutral => const _StatusStyle(
        icon: Icons.info_outline,
        foreground: Color(0xFF515866),
        background: Color(0xFFF3F5F8),
        border: Color(0xFFD5DAE3),
      ),
      AppStatusType.info => const _StatusStyle(
        icon: Icons.info_outline,
        foreground: AppColors.info,
        background: Color(0xFFEAF2FF),
        border: Color(0xFFA9C5F2),
      ),
      AppStatusType.success => const _StatusStyle(
        icon: Icons.check_circle_outline,
        foreground: AppColors.success,
        background: Color(0xFFE8F5ED),
        border: Color(0xFFA5D6B8),
      ),
      AppStatusType.warning => const _StatusStyle(
        icon: Icons.warning_amber_outlined,
        foreground: AppColors.warning,
        background: Color(0xFFFFF8DF),
        border: Color(0xFFE6CE81),
      ),
      AppStatusType.error => const _StatusStyle(
        icon: Icons.error_outline,
        foreground: AppColors.error,
        background: Color(0xFFFFEBEE),
        border: Color(0xFFEF9A9A),
      ),
    };
  }
}

class _StatusStyle {
  const _StatusStyle({
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
