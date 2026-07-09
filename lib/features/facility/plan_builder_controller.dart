import 'package:flutter/material.dart';

import '../../app/state/app_state.dart';
import '../../domain/entities/facility.dart';

class PlanBuilderController extends ChangeNotifier {
  PlanBuilderController(this._appState) {
    _appState.addListener(_onAppStateChanged);
  }

  final AppState _appState;

  int get selectedCount => _appState.selectedFacilityCount;

  List<Facility> get selectedFacilities => _appState.selectedFacilities;

  bool isSelected(String facilityId) {
    return _appState.isFacilitySelected(facilityId);
  }

  void addFacility(Facility facility) {
    _appState.addFacility(facility);
  }

  void removeFacility(String facilityId) {
    _appState.removeFacility(facilityId);
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