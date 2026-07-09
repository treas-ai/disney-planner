import 'package:flutter/foundation.dart';

import '../../domain/entities/facility.dart';
import '../../domain/entities/plan_preference.dart';
import '../../domain/enums/preferred_time.dart';
import '../../domain/enums/priority_level.dart';
import '../../domain/enums/wait_tolerance.dart';

class PlanPreferenceController extends ChangeNotifier {
  final Map<String, PlanPreference> _preferencesByFacilityId = {};

  List<PlanPreference> get preferences {
    return List.unmodifiable(_preferencesByFacilityId.values);
  }

  PlanPreference? getPreference(String facilityId) {
    return _preferencesByFacilityId[facilityId];
  }

  void ensurePreference(Facility facility) {
    if (_preferencesByFacilityId.containsKey(facility.id)) {
      return;
    }

    _preferencesByFacilityId[facility.id] = PlanPreference.initial(
      facilityId: facility.id,
    );

    notifyListeners();
  }

  void removePreference(String facilityId) {
    _preferencesByFacilityId.remove(facilityId);
    notifyListeners();
  }

  void updatePriority({
    required String facilityId,
    required PriorityLevel priority,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(
      priority: priority,
    );

    notifyListeners();
  }

  void updatePreferredTime({
    required String facilityId,
    required PreferredTime preferredTime,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(
      preferredTime: preferredTime,
    );

    notifyListeners();
  }

  void updateWaitTolerance({
    required String facilityId,
    required WaitTolerance waitTolerance,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(
      waitTolerance: waitTolerance,
    );

    notifyListeners();
  }

  void updateUseDpa({
    required String facilityId,
    required bool value,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(
      useDpa: value,
    );

    notifyListeners();
  }

  void updateUsePriorityPass({
    required String facilityId,
    required bool value,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(
      usePriorityPass: value,
    );

    notifyListeners();
  }

  void updateMemo({
    required String facilityId,
    required String memo,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(
      memo: memo,
    );

    notifyListeners();
  }
}