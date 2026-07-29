import 'package:flutter/foundation.dart';

import '../../app/state/app_state.dart';
import '../../domain/entities/facility.dart';

class PlanBuilderController extends ChangeNotifier {
  PlanBuilderController(this._appState) {
    _appState.addListener(_onAppStateChanged);
  }

  final AppState _appState;

  List<Facility> get selectedFacilities {
    return _appState.selectedFacilities;
  }

  int get selectedFacilityCount {
    return _appState.selectedFacilityCount;
  }

  bool get isSaving {
    return _appState.isSaving;
  }

  List<Facility> selectedFacilitiesForPark(String parkId) {
    return _appState.selectedFacilitiesForPark(parkId);
  }

  int selectedFacilityCountForPark(String parkId) {
    return _appState.selectedFacilityCountForPark(parkId);
  }

  bool isSelected(String facilityId) {
    return _appState.isFacilitySelected(facilityId);
  }

  void addFacility(Facility facility) {
    _appState.addFacility(facility);
  }

  void removeFacility(String facilityId) {
    _appState.removeFacility(facilityId);
  }

  void reorderFacilitiesForPark({
    required String parkId,
    required int oldIndex,
    required int newIndex,
  }) {
    _appState.reorderSelectedFacilitiesForPark(
      parkId: parkId,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
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
