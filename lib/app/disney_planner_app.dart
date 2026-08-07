import 'package:flutter/material.dart';
import '../data/local/onboarding_preferences.dart';
import '../features/onboarding/onboarding_screen.dart';
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
  final OnboardingPreferences _onboardingPreferences =
      const OnboardingPreferences();
  bool _onboardingChecked = false;
  bool _onboardingCompleted = true;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
    _restoreAppState();
  }

  Future<void> _restoreAppState() async {
    await _appState.restore();
    final completed = await _onboardingPreferences.isCompleted();
    if (!mounted) {
      return;
    }
    setState(() {
      _onboardingCompleted = completed;
      _onboardingChecked = true;
    });
  }

  Future<void> _completeOnboarding() async {
    await _onboardingPreferences.complete();
    if (!mounted) {
      return;
    }
    setState(() => _onboardingCompleted = true);
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
        home: AnimatedBuilder(
          animation: _appState,
          builder: (context, _) {
            if (!_appState.isRestored || !_onboardingChecked) {
              return const _RestoreLoadingScreen();
            }

            if (!_onboardingCompleted) {
              return OnboardingScreen(onCompleted: _completeOnboarding);
            }

            return const MainShell();
          },
        ),
      ),
    );
  }
}

class _RestoreLoadingScreen extends StatelessWidget {
  const _RestoreLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('データを復元中です...')));
  }
}
