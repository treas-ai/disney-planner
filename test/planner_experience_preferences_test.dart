import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disney_planner/data/local/planner_experience_preferences.dart';

void main() {
  const preferences = PlannerExperiencePreferences();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('defaults to beginner when no mode has been saved', () async {
    expect(await preferences.hasSavedMode(), isFalse);
    expect(await preferences.loadMode(), PlannerExperienceMode.beginner);
  });

  test('saves and restores detailed mode', () async {
    await preferences.saveMode(PlannerExperienceMode.detailed);
    expect(await preferences.hasSavedMode(), isTrue);
    expect(await preferences.loadMode(), PlannerExperienceMode.detailed);
  });
}
