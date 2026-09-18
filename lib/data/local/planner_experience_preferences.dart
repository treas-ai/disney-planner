import 'package:shared_preferences/shared_preferences.dart';

enum PlannerExperienceMode { beginner, detailed }

class PlannerExperiencePreferences {
  const PlannerExperiencePreferences();

  static const _modeKey = 'planner_experience_mode_v1';

  Future<bool> hasSavedMode() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.containsKey(_modeKey);
  }

  Future<PlannerExperienceMode> loadMode() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_modeKey);
    return raw == PlannerExperienceMode.detailed.name
        ? PlannerExperienceMode.detailed
        : PlannerExperienceMode.beginner;
  }

  Future<void> saveMode(PlannerExperienceMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_modeKey, mode.name);
  }
}
