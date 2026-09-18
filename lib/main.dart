import 'package:flutter/material.dart';

import 'app/app_theme.dart';
import 'app/main_shell.dart';
import 'app/state/app_state.dart';
import 'app/state/app_state_scope.dart';
import 'data/local/onboarding_preferences.dart';
import 'data/local/planner_experience_preferences.dart';
import 'features/onboarding/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appState = AppState();
  await appState.restore();

  runApp(DisneyPlannerApp(appState: appState));
}

class DisneyPlannerApp extends StatefulWidget {
  const DisneyPlannerApp({super.key, required this.appState});

  final AppState appState;

  @override
  State<DisneyPlannerApp> createState() => _DisneyPlannerAppState();
}

class _DisneyPlannerAppState extends State<DisneyPlannerApp> {
  final OnboardingPreferences _onboardingPreferences =
      const OnboardingPreferences();
  final PlannerExperiencePreferences _experiencePreferences =
      const PlannerExperiencePreferences();

  bool _checked = false;
  bool _completed = true;
  PlannerExperienceMode _mode = PlannerExperienceMode.beginner;

  @override
  void initState() {
    super.initState();
    _restoreExperience();
  }

  Future<void> _restoreExperience() async {
    final completed = await _onboardingPreferences.isCompleted();
    final hasSavedMode = await _experiencePreferences.hasSavedMode();
    final savedMode = await _experiencePreferences.loadMode();
    if (!mounted) return;
    setState(() {
      _completed = completed;
      // Existing users keep the current detailed UI until they explicitly
      // rerun onboarding and choose beginner mode.
      _mode = completed && !hasSavedMode
          ? PlannerExperienceMode.detailed
          : savedMode;
      _checked = true;
    });
  }

  Future<void> _completeOnboarding(PlannerExperienceMode mode) async {
    await _experiencePreferences.saveMode(mode);
    await _onboardingPreferences.complete();
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _completed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      appState: widget.appState,
      child: MaterialApp(
        title: 'Disney Planner',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: !_checked
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : !_completed
            ? OnboardingScreen(onCompleted: _completeOnboarding)
            : MainShell(beginnerMode: _mode == PlannerExperienceMode.beginner),
      ),
    );
  }
}
