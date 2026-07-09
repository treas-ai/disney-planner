import 'package:flutter/material.dart';

import 'app_state.dart';

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState appState,
    required super.child,
  }) : super(notifier: appState);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();

    assert(
      scope != null,
      'AppStateScopeが見つかりません。DisneyPlannerAppでAppStateScopeを設定してください。',
    );

    return scope!.notifier!;
  }

  static AppState read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<AppStateScope>();
    final widget = element?.widget;

    assert(
      widget is AppStateScope,
      'AppStateScopeが見つかりません。DisneyPlannerAppでAppStateScopeを設定してください。',
    );

    return (widget as AppStateScope).notifier!;
  }
}