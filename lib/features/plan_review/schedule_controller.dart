import 'package:flutter/foundation.dart';

import '../../data/datasources/mock/mock_facility_data_source.dart';
import '../../domain/entities/day_schedule.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/plan_preference.dart';
import '../../domain/entities/trip_settings.dart';
import '../../domain/enums/preferred_time.dart';
import '../../domain/enums/priority_level.dart';
import '../../domain/enums/wait_tolerance.dart';
import '../../domain/services/schedule_engine.dart';

class ScheduleController extends ChangeNotifier {
  ScheduleController();

  final ScheduleEngine _scheduleEngine = const ScheduleEngine();

  bool isLoading = false;
  String? errorMessage;

  DaySchedule? schedule;

  Future<void> generateDemoSchedule() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final facilities = _createDemoFacilities();
      final preferences = _createDemoPreferences(facilities);
      final settings = TripSettings.initial();

      schedule = _scheduleEngine.generate(
        settings: settings,
        facilities: facilities,
        preferences: preferences,
      );
    } catch (_) {
      errorMessage = 'スケジュール生成に失敗しました。';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  List<Facility> _createDemoFacilities() {
    return MockFacilityDataSource().getFacilities();
  }

  List<PlanPreference> _createDemoPreferences(List<Facility> facilities) {
    return facilities.map((facility) {
      final priority = facility.id.contains('soaring')
          ? PriorityLevel.highest
          : PriorityLevel.high;

      final preferredTime = facility.id.contains('big_band_beat')
          ? PreferredTime.afternoon
          : PreferredTime.anytime;

      return PlanPreference(
        id: 'demo_preference_${facility.id}',
        facilityId: facility.id,
        priority: priority,
        preferredTime: preferredTime,
        waitTolerance: WaitTolerance.medium,
        useDpa: facility.reservation != null,
        usePriorityPass: false,
        memo: '',
        createdAt: DateTime.now(),
      );
    }).toList();
  }
}