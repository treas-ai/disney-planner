import '../entities/facility.dart';
import '../entities/plan_preference.dart';
import '../entities/performance_time_option.dart';
import '../enums/facility_category.dart';
import '../enums/fixed_time_status.dart';
import '../repositories/performance_schedule_repository.dart';

class OfficialPerformancePreferenceResolver {
  const OfficialPerformancePreferenceResolver({required this.repository});

  final PerformanceScheduleRepository repository;

  Future<List<PlanPreference>> resolve({
    required String parkId,
    required DateTime date,
    required int entryMinutes,
    required int exitMinutes,
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
  }) async {
    final preferenceById = {
      for (final preference in preferences) preference.facilityId: preference,
    };

    for (final facility in facilities) {
      if (!_isPerformance(facility)) {
        continue;
      }

      final current =
          preferenceById[facility.id] ??
          PlanPreference.initial(facilityId: facility.id);

      if (current.fixedTimeStatus == FixedTimeStatus.confirmed &&
          current.hasPreferredPerformanceTime) {
        continue;
      }

      final options = await repository.findOptions(
        parkId: parkId,
        facilityId: facility.id,
        date: date,
      );
      final selected = _selectOption(
        options: options,
        selectedPerformanceIndex: current.selectedPerformanceIndex,
        entryMinutes: entryMinutes,
        exitMinutes: exitMinutes,
      );
      if (selected == null) {
        continue;
      }

      preferenceById[facility.id] = current.copyWith(
        fixedTimeStatus: FixedTimeStatus.confirmed,
        selectedPerformanceIndex: selected.performanceIndex,
        preferredPerformanceTime: selected.startTime,
      );
    }

    return List<PlanPreference>.unmodifiable(preferenceById.values);
  }

  PerformanceTimeOption? _selectOption({
    required List<PerformanceTimeOption> options,
    required int? selectedPerformanceIndex,
    required int entryMinutes,
    required int exitMinutes,
  }) {
    if (options.isEmpty) {
      return null;
    }

    if (selectedPerformanceIndex != null) {
      for (final option in options) {
        if (option.performanceIndex == selectedPerformanceIndex) {
          return option;
        }
      }
    }

    for (final option in options) {
      final minutes = _parseTime(option.startTime);
      if (minutes != null &&
          minutes >= entryMinutes &&
          minutes <= exitMinutes) {
        return option;
      }
    }

    return null;
  }

  bool _isPerformance(Facility facility) {
    return facility.category == FacilityCategory.show ||
        facility.category == FacilityCategory.parade;
  }

  int? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return hour * 60 + minute;
  }
}
