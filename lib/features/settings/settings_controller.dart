import 'package:flutter/material.dart';

import '../../app/state/app_state.dart';
import '../../domain/entities/trip_settings.dart';

class SettingsController extends ChangeNotifier {
      SettingsController(this._appState) {
    _appState.addListener(_onAppStateChanged);
  }

  final AppState _appState;

  TripSettings get settings => _appState.tripSettings;

  void _onAppStateChanged() {
    notifyListeners();
  }

  void updatePark(String parkId) {
    _appState.updateTripSettings(settings.copyWith(parkId: parkId));
  }

  void updateEntryTime(TimeOfDay time) {
    _appState.updateTripSettings(
      settings.copyWith(
        entryTimeHour: time.hour,
        entryTimeMinute: time.minute,
      ),
    );
  }

  void updateExitTime(TimeOfDay time) {
    _appState.updateTripSettings(
      settings.copyWith(
        exitTimeHour: time.hour,
        exitTimeMinute: time.minute,
      ),
    );
  }

  void increasePeople() {
    if (settings.numberOfPeople >= 10) {
      return;
    }

    _appState.updateTripSettings(
      settings.copyWith(numberOfPeople: settings.numberOfPeople + 1),
    );
  }

  void decreasePeople() {
    if (settings.numberOfPeople <= 1) {
      return;
    }

    _appState.updateTripSettings(
      settings.copyWith(numberOfPeople: settings.numberOfPeople - 1),
    );
  }

  void updateHappyEntry(bool value) {
    _appState.updateTripSettings(settings.copyWith(hasHappyEntry: value));
  }

  void updateDpa(bool value) {
    _appState.updateTripSettings(settings.copyWith(canUseDpa: value));
  }

  void updatePriorityPass(bool value) {
    _appState.updateTripSettings(
      settings.copyWith(canUsePriorityPass: value),
    );
  }

  void updateSingleRider(bool value) {
    _appState.updateTripSettings(
      settings.copyWith(canUseSingleRider: value),
    );
  }

  void updateLunch(bool value) {
    _appState.updateTripSettings(settings.copyWith(wantsLunch: value));
  }

  void updateDinner(bool value) {
    _appState.updateTripSettings(settings.copyWith(wantsDinner: value));
  }

  void updateRainy(bool value) {
    _appState.updateTripSettings(settings.copyWith(isRainy: value));
  }

  void updateChildren(bool value) {
    _appState.updateTripSettings(settings.copyWith(hasChildren: value));
  }

  @override
  void dispose() {
    _appState.removeListener(_onAppStateChanged);
    super.dispose();
  }
}