import 'package:flutter/material.dart';

import '../../app/state/app_state.dart';
import '../../app/dependency/service_locator.dart';
import '../../data/local/onboarding_preferences.dart';
import '../../domain/entities/trip_settings.dart';
import '../../domain/entities/planning_scenario.dart';
import '../../domain/enums/preferred_time.dart';
import '../../domain/enums/live_data_source_type.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._appState) {
    _appState.addListener(_onAppStateChanged);
    _restoreLiveDataSource();
  }

  final AppState _appState;

  LiveDataSourceType liveDataSource = LiveDataSourceType.mock;
  bool isLoadingLiveDataSource = true;

  TripSettings get settings {
    return _appState.tripSettings;
  }

  TripSettings get newVisitDayDefaults => _appState.newVisitDayDefaults;

  AppState get appState => _appState;

  List<String> get visitDayIds => _appState.visitDayIds;
  String get activeVisitDayId => _appState.activeVisitDayId;

  Future<void> addVisitDay(DateTime date) {
    return _appState.addVisitDay(date: date);
  }

  void updateNewVisitDayDefaults(TripSettings settings) {
    _appState.updateNewVisitDayDefaults(settings);
  }

  Future<void> switchVisitDay(String dayId) => _appState.switchVisitDay(dayId);
  Future<void> removeVisitDay(String dayId) => _appState.removeVisitDay(dayId);
  void updateVisitDate(DateTime date) => _appState.updateActiveVisitDate(date);

  Future<void> resetOnboarding() {
    return const OnboardingPreferences().reset();
  }

  void _onAppStateChanged() {
    notifyListeners();
  }

  void updateScheduleOptimizationMode(ScheduleOptimizationMode mode) {
    _appState.updateTripSettings(
      settings.copyWith(scheduleOptimizationMode: mode),
    );
  }

  void updatePark(String parkId) {
    _appState.updateTripSettings(settings.copyWith(parkId: parkId));
  }

  void updateQueueArrivalTime(TimeOfDay time) {
    _appState.updateTripSettings(
      settings.copyWith(
        queueArrivalTimeHour: time.hour,
        queueArrivalTimeMinute: time.minute,
      ),
    );
  }

  void updateHappyEntryTime(TimeOfDay time) {
    _appState.updateTripSettings(
      settings.copyWith(
        happyEntryTimeHour: time.hour,
        happyEntryTimeMinute: time.minute,
      ),
    );
  }

  void updateEntryTime(TimeOfDay time) {
    _appState.updateTripSettings(
      settings.copyWith(entryTimeHour: time.hour, entryTimeMinute: time.minute),
    );
  }

  void updateExitTime(TimeOfDay time) {
    _appState.updateTripSettings(
      settings.copyWith(exitTimeHour: time.hour, exitTimeMinute: time.minute),
    );
  }

  void updateOfficialClosingTime(TimeOfDay time) {
    final closingMinutes = time.hour * 60 + time.minute;
    final exitMinutes = settings.exitTimeHour * 60 + settings.exitTimeMinute;

    _appState.updateTripSettings(
      settings.copyWith(
        officialClosingTimeHour: time.hour,
        officialClosingTimeMinute: time.minute,
        exitTimeHour: exitMinutes > closingMinutes
            ? time.hour
            : settings.exitTimeHour,
        exitTimeMinute: exitMinutes > closingMinutes
            ? time.minute
            : settings.exitTimeMinute,
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

  void updatePlanningBudgetMode(PlanningBudgetMode mode) {
    _appState.updateTripSettings(settings.copyWith(planningBudgetMode: mode));
  }

  void updateMaxExtraBudgetYen(int value) {
    _appState.updateTripSettings(
      settings.copyWith(maxExtraBudgetYen: value.clamp(0, 50000).toInt()),
    );
  }

  void updateAttractionDpaMaxUses(int value) {
    final safeValue = value.clamp(0, 3).toInt();
    _appState.updateTripSettings(
      settings.copyWith(
        canUseDpa: safeValue > 0,
        attractionDpaMaxUses: safeValue,
      ),
    );
  }

  void updatePriorityPass(bool value) {
    _appState.updateTripSettings(settings.copyWith(canUsePriorityPass: value));
  }

  void updateSingleRider(bool value) {
    _appState.updateTripSettings(settings.copyWith(canUseSingleRider: value));
  }

  void updateVacationPackage(bool value) {
    _appState.updateTripSettings(
      settings.copyWith(
        usesVacationPackage: value,
        hasUnlimitedAttractionRides:
            value ? settings.hasUnlimitedAttractionRides : false,
        usesFreeDrinkBenefit: value ? settings.usesFreeDrinkBenefit : false,
        hasAttractionVoucher: value ? settings.hasAttractionVoucher : false,
        hasShowVoucher: value ? settings.hasShowVoucher : false,
        hasRestaurantReservation: value
            ? settings.hasRestaurantReservation
            : false,
      ),
    );
  }

  void updateUnlimitedAttractionRides(bool value) {
    _appState.updateTripSettings(
      settings.copyWith(
        usesVacationPackage: value ? true : settings.usesVacationPackage,
        hasUnlimitedAttractionRides: value,
      ),
    );
  }

  void updateFreeDrinkBenefit(bool value) {
    _appState.updateTripSettings(
      settings.copyWith(usesFreeDrinkBenefit: value),
    );
  }

  void updateAttractionVoucher(bool value) {
    _appState.updateTripSettings(
      settings.copyWith(hasAttractionVoucher: value),
    );
  }

  void updateShowVoucher(bool value) {
    _appState.updateTripSettings(settings.copyWith(hasShowVoucher: value));
  }

  void updateRestaurantReservation(bool value) {
    _appState.updateTripSettings(
      settings.copyWith(hasRestaurantReservation: value),
    );
  }

  void updateBreakfast(bool value) {
    _appState.updateTripSettings(settings.copyWith(wantsBreakfast: value));
  }

  void updateLunch(bool value) {
    _appState.updateTripSettings(settings.copyWith(wantsLunch: value));
  }

  void updateDinner(bool value) {
    _appState.updateTripSettings(settings.copyWith(wantsDinner: value));
  }

  void updateFreeTimeEnabled(bool value) {
    final current = settings.freeTimePreference;
    _appState.updateTripSettings(
      settings.copyWith(
        freeTimePreference: current.copyWith(
          enabled: value,
          targetMinutes: value && current.targetMinutes <= 0
              ? 60
              : current.targetMinutes,
          minimumBlockMinutes: value && current.targetMinutes <= 0
              ? 60
              : current.minimumBlockMinutes,
        ),
      ),
    );
  }

  void updateFreeTimeTargetMinutes(int minutes) {
    final safeMinutes = minutes.clamp(30, 90).toInt();
    _appState.updateTripSettings(
      settings.copyWith(
        freeTimePreference: settings.freeTimePreference.copyWith(
          enabled: true,
          targetMinutes: safeMinutes,
          minimumBlockMinutes: safeMinutes,
        ),
      ),
    );
  }

  void updateFreeTimePreferredTime(PreferredTime value) {
    _appState.updateTripSettings(
      settings.copyWith(
        freeTimePreference: settings.freeTimePreference.copyWith(
          enabled: true,
          preferredTime: value,
        ),
      ),
    );
  }

  void updateRainy(bool value) {
    _appState.updateTripSettings(settings.copyWith(isRainy: value));
  }

  void updateChildren(bool value) {
    _appState.updateTripSettings(settings.copyWith(hasChildren: value));
  }

  Future<void> _restoreLiveDataSource() async {
    liveDataSource = await ServiceLocator.liveDataSourcePreferences.load();
    isLoadingLiveDataSource = false;
    notifyListeners();
  }

  Future<void> updateLiveDataSource(LiveDataSourceType value) async {
    if (liveDataSource == value) {
      return;
    }

    liveDataSource = value;
    ServiceLocator.clearLiveDataCache();
    notifyListeners();
    await ServiceLocator.liveDataSourcePreferences.save(value);
  }

  @override
  void dispose() {
    _appState.removeListener(_onAppStateChanged);
    super.dispose();
  }
}
