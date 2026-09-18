import '../entities/day_schedule.dart';
import '../entities/facility.dart';
import '../entities/plan_preference.dart';
import '../entities/schedule_item.dart';
import '../entities/schedule_validation_issue.dart';
import '../entities/trip_settings.dart';
import '../enums/fixed_time_status.dart';
import '../enums/schedule_validation_severity.dart';

class ScheduleValidator {
  const ScheduleValidator();

  List<ScheduleValidationIssue> validate({
    required DaySchedule schedule,
    required TripSettings settings,
    required List<PlanPreference> preferences,
    List<Facility> facilities = const <Facility>[],
  }) {
    final issues = <ScheduleValidationIssue>[];
    final items = [...schedule.items]
      ..sort((left, right) => _start(left).compareTo(_start(right)));

    for (var index = 1; index < items.length; index++) {
      final previous = items[index - 1];
      final current = items[index];
      if (_start(current) < _end(previous)) {
        issues.add(
          ScheduleValidationIssue(
            code: 'schedule_overlap',
            severity: ScheduleValidationSeverity.error,
            message: '${previous.title}と${current.title}の時間が重複しています。',
          ),
        );
      }
    }

    final entryMinutes = settings.entryTimeHour * 60 + settings.entryTimeMinute;
    final exitMinutes = settings.exitTimeHour * 60 + settings.exitTimeMinute;

    for (final item in items) {
      if (_start(item) < entryMinutes && item.type.name != 'entry') {
        issues.add(
          ScheduleValidationIssue(
            code: 'before_entry',
            severity: ScheduleValidationSeverity.warning,
            message: '${item.title}が入園予定時刻より前に配置されています。',
          ),
        );
      }
      if (_end(item) > exitMinutes && item.type.name != 'exit') {
        issues.add(
          ScheduleValidationIssue(
            code: 'after_exit',
            severity: ScheduleValidationSeverity.warning,
            message: '${item.title}が設定した退園時刻を越えています。',
          ),
        );
      }
    }

    final preferenceById = {
      for (final preference in preferences) preference.facilityId: preference,
    };
    final facilityById = {for (final facility in facilities) facility.id: facility};
    for (final item in items) {
      final facilityId = item.facilityId;
      if (facilityId == null) {
        continue;
      }
      final preference = preferenceById[facilityId];
      if (preference == null ||
          preference.fixedTimeStatus != FixedTimeStatus.confirmed) {
        continue;
      }

      final expected = preference.preferredPerformanceTime.trim().isNotEmpty
          ? preference.preferredPerformanceTime.trim()
          : preference.reservationTime.trim().isNotEmpty
          ? preference.reservationTime.trim()
          : preference.scheduledAccessTime.trim();

      if (expected.isNotEmpty) {
        final facility = facilityById[facilityId];
        final expectedMinutes = _parse(expected);
        final expectedItemStart =
            facility != null &&
                facility.requiresParkExit &&
                preference.reservationTime.trim().isNotEmpty &&
                expectedMinutes != null
            ? expectedMinutes - facility.outboundTravelMinutes
            : expectedMinutes;
        if (expectedItemStart != null && _start(item) != expectedItemStart) {
          final message = facility != null && facility.requiresParkExit
              ? '${item.title}は予約$expectedに対して、外出開始が${item.startTimeLabel}です。往路移動時間を確認してください。'
              : '${item.title}は固定予定$expectedですが、${item.startTimeLabel}に配置されています。';
          issues.add(
            ScheduleValidationIssue(
              code: 'fixed_time_mismatch',
              severity: ScheduleValidationSeverity.error,
              message: message,
            ),
          );
        }
      }
    }

    final scheduledFacilityIds = items
        .map((item) => item.facilityId)
        .whereType<String>()
        .toSet();
    for (final facility in facilities) {
      final preference = preferenceById[facility.id];
      if (preference?.isExcluded == true) continue;
      if (!scheduledFacilityIds.contains(facility.id)) {
        issues.add(
          ScheduleValidationIssue(
            code: 'desired_facility_missing',
            severity: ScheduleValidationSeverity.warning,
            message: '今回は「${facility.name}」をプランに入れられませんでした。予定は「やりたいこと」に残しています。',
          ),
        );
      }
    }

    if (issues.isEmpty) {
      issues.add(
        const ScheduleValidationIssue(
          code: 'schedule_valid',
          severity: ScheduleValidationSeverity.information,
          message: '時間の重複や固定予定の矛盾は見つかりませんでした。',
        ),
      );
    }

    return List<ScheduleValidationIssue>.unmodifiable(issues);
  }

  int? _parse(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  int _start(ScheduleItem item) => item.startHour * 60 + item.startMinute;
  int _end(ScheduleItem item) => item.endHour * 60 + item.endMinute;
}
