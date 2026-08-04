import '../entities/day_schedule.dart';
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

      if (expected.isNotEmpty && item.startTimeLabel != expected) {
        issues.add(
          ScheduleValidationIssue(
            code: 'fixed_time_mismatch',
            severity: ScheduleValidationSeverity.error,
            message:
                '${item.title}は固定予定$expectedですが、'
                '${item.startTimeLabel}に配置されています。',
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

  int _start(ScheduleItem item) => item.startHour * 60 + item.startMinute;
  int _end(ScheduleItem item) => item.endHour * 60 + item.endMinute;
}
