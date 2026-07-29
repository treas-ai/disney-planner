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
        final horizontalPadding = _horizontalPadding(
          constraints.maxWidth,
        );

        final resolvedPadding =
            padding ??
            EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.md,
              horizontalPadding,
              includeBottomSafeArea
                  ? AppSpacing.md
                  : 0,
            );

        Widget result = Padding(
          padding: resolvedPadding,
          child: child,
        );

        if (centerContent) {
          result = Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxContentWidth,
              ),
              child: result,
            ),
          );
        }

        return result;
      },
    );

    if (useSafeArea) {
      content = SafeArea(
        bottom: includeBottomSafeArea,
        child: content,
      );
    }

    return content;
  }

  double _horizontalPadding(
    double width,
  ) {
    if (width >= 1200) {
      return AppSpacing.pageDesktop;
    }

    if (width >= 700) {
      return AppSpacing.pageTablet;
    }

    return AppSpacing.pageMobile;
  }
}