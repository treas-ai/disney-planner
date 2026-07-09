import 'package:flutter/material.dart';

import '../../domain/entities/trip_settings.dart';

class SettingsController extends ChangeNotifier {
  TripSettings settings = TripSettings.initial();

  void updatePark(String parkId) {
    settings = settings.copyWith(parkId: parkId);
    notifyListeners();
  }

  void updateEntryTime(TimeOfDay time) {
    settings = settings.copyWith(
      entryTimeHour: time.hour,
      entryTimeMinute: time.minute,
    );
    notifyListeners();
  }

  void updateExitTime(TimeOfDay time) {
    settings = settings.copyWith(
      exitTimeHour: time.hour,
      exitTimeMinute: time.minute,
    );
    notifyListeners();
  }

  void increasePeople() {
    if (settings.numberOfPeople >= 10) {
      return;
    }

    settings = settings.copyWith(
      numberOfPeople: settings.numberOfPeople + 1,
    );
    notifyListeners();
  }

  void decreasePeople() {
    if (settings.numberOfPeople <= 1) {
      return;
    }

    settings = settings.copyWith(
      numberOfPeople: settings.numberOfPeople - 1,
    );
    notifyListeners();
  }

  void updateHappyEntry(bool value) {
    settings = settings.copyWith(hasHappyEntry: value);
    notifyListeners();
  }

  void updateDpa(bool value) {
    settings = settings.copyWith(canUseDpa: value);
    notifyListeners();
  }

  void updatePriorityPass(bool value) {
    settings = settings.copyWith(canUsePriorityPass: value);
    notifyListeners();
  }

  void updateSingleRider(bool value) {
    settings = settings.copyWith(canUseSingleRider: value);
    notifyListeners();
  }

  void updateLunch(bool value) {
    settings = settings.copyWith(wantsLunch: value);
    notifyListeners();
  }

  void updateDinner(bool value) {
    settings = settings.copyWith(wantsDinner: value);
    notifyListeners();
  }

  void updateRainy(bool value) {
    settings = settings.copyWith(isRainy: value);
    notifyListeners();
  }

  void updateChildren(bool value) {
    settings = settings.copyWith(hasChildren: value);
    notifyListeners();
  }
}