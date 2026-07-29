import 'package:flutter/material.dart';

import 'app/app_theme.dart';
import 'app/main_shell.dart';
import 'app/state/app_state.dart';
import 'app/state/app_state_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appState = AppState();

  await appState.restore();

  runApp(DisneyPlannerApp(appState: appState));
}

class DisneyPlannerApp extends StatelessWidget {
  const DisneyPlannerApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      appState: appState,
      child: MaterialApp(
        title: 'Disney Planner',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: const MainShell(),
      ),
    );
  }
}
