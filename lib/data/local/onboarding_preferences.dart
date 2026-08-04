import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPreferences {
  const OnboardingPreferences();

  static const _key = 'onboarding_completed_v1';

  Future<bool> isCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_key) ?? false;
  }

  Future<void> complete() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key, true);
  }

  Future<void> reset() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }
}
