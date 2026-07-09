import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'main_shell.dart';
import 'state/app_state.dart';
import 'state/app_state_scope.dart';

class DisneyPlannerApp extends StatefulWidget {
  const DisneyPlannerApp({super.key});

  @override
  State<DisneyPlannerApp> createState() => _DisneyPlannerAppState();
}

class _DisneyPlannerAppState extends State<DisneyPlannerApp> {
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      appState: _appState,
      child: MaterialApp(
        title: 'Disney Planner',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const MainShell(),
      ),
    );
  }
}