import 'package:flutter/material.dart';

import '../../app/state/app_state.dart';
import '../../domain/entities/plan_preference.dart';
import '../../domain/enums/meal_preference.dart';
import '../../domain/enums/preferred_time.dart';
import '../../domain/enums/priority_level.dart';
import '../../domain/enums/wait_tolerance.dart';

class PlanPreferenceController extends ChangeNotifier {
  PlanPreferenceController(this._appState) {
    _appState.addListener(_onAppStateChanged);
  }

  final AppState _appState;

  List<PlanPreference> get preferences {
    return _appState.planPreferences;
  }

  PlanPreference? getPreference(String facilityId) {
    return _appState.getPreference(facilityId);
  }

  void updatePriority({
    required String facilityId,
    required PriorityLevel priority,
  }) {
    _appState.updatePreferencePriority(
      facilityId: facilityId,
      priority: priority,
    );
  }

  void updatePreferredTime({
    required String facilityId,
    required PreferredTime preferredTime,
  }) {
    _appState.updatePreferencePreferredTime(
      facilityId: facilityId,
      preferredTime: preferredTime,
    );
  }

  void updateWaitTolerance({
    required String facilityId,
    required WaitTolerance waitTolerance,
  }) {
    _appState.updatePreferenceWaitTolerance(
      facilityId: facilityId,
      waitTolerance: waitTolerance,
    );
  }

  void updateMealPreference({
    required String facilityId,
    required MealPreference mealPreference,
  }) {
    _appState.updatePreferenceMealPreference(
      facilityId: facilityId,
      mealPreference: mealPreference,
    );
  }

  void updateUseDpa({required String facilityId, required bool value}) {
    _appState.updatePreferenceUseDpa(facilityId: facilityId, value: value);
  }

  void updateUsePriorityPass({
    required String facilityId,
    required bool value,
  }) {
    _appState.updatePreferenceUsePriorityPass(
      facilityId: facilityId,
      value: value,
    );
  }

  void updateUseStandbyPass({required String facilityId, required bool value}) {
    _appState.updatePreferenceUseStandbyPass(
      facilityId: facilityId,
      value: value,
    );
  }

  void updatePrioritizeCapsuleToy({
    required String facilityId,
    required bool value,
  }) {
    _appState.updatePreferencePrioritizeCapsuleToy(
      facilityId: facilityId,
      value: value,
    );
  }

  void updateMemo({required String facilityId, required String memo}) {
    _appState.updatePreferenceMemo(facilityId: facilityId, memo: memo);
  }

  void _onAppStateChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _appState.removeListener(_onAppStateChanged);

    super.dispose();
  }
}
