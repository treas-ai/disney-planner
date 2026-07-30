import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.padding,
    this.maxContentWidth = 1440,
    this.useSafeArea = true,
    this.centerContent = true,
    this.includeBottomSafeArea = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double maxContentWidth;
  final bool useSafeArea;
  final bool centerContent;
  final bool includeBottomSafeArea;

  @override
  Widget build(BuildContext context) {
    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final layoutPadding = _layoutPadding(constraints.maxWidth);

        final resolvedPadding =
            padding ??
            EdgeInsets.fromLTRB(
              layoutPadding.horizontal,
              layoutPadding.top,
              layoutPadding.horizontal,
              includeBottomSafeArea ? layoutPadding.bottom : 0,
            );

        Widget result = Padding(padding: resolvedPadding, child: child);

        if (centerContent) {
          result = Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: result,
            ),
          );
        }

        return result;
      },
    );

    if (useSafeArea) {
      content = SafeArea(bottom: includeBottomSafeArea, child: content);
    }

    return content;
  }

  _AppScaffoldPadding _layoutPadding(double width) {
    if (width >= 1200) {
      return const _AppScaffoldPadding(
        horizontal: AppSpacing.pageDesktop,
        top: AppSpacing.md,
        bottom: AppSpacing.md,
      );
    }

    if (width >= 700) {
      return const _AppScaffoldPadding(
        horizontal: AppSpacing.pageTablet,
        top: AppSpacing.md,
        bottom: AppSpacing.md,
      );
    }

    if (width >= 430) {
      return const _AppScaffoldPadding(horizontal: 10, top: 10, bottom: 10);
    }

    return const _AppScaffoldPadding(horizontal: 7, top: 7, bottom: 7);
  }
}

class _AppScaffoldPadding {
  const _AppScaffoldPadding({
    required this.horizontal,
    required this.top,
    required this.bottom,
  });

  final double horizontal;
  final double top;
  final double bottom;
}
