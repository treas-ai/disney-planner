import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.card),
    this.margin = EdgeInsets.zero,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.elevation = 0,
    this.clipBehavior = Clip.antiAlias,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadiusGeometry? borderRadius;
  final double elevation;
  final Clip clipBehavior;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final resolvedRadius =
        borderRadius ?? BorderRadius.circular(AppRadius.card);

    final content = Padding(padding: padding, child: child);

    return Container(
      width: double.infinity,
      margin: margin,
      child: Material(
        color: backgroundColor ?? colorScheme.surface,
        elevation: elevation,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: resolvedRadius,
          side: BorderSide(color: borderColor ?? colorScheme.outlineVariant),
        ),
        clipBehavior: clipBehavior,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
