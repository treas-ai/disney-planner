import 'day_schedule.dart';
import 'schedule_change.dart';
import 'schedule_item.dart';

class ScheduleRecalculationResult {
  const ScheduleRecalculationResult({
    required this.beforeSchedule,
    required this.afterSchedule,
    required this.preservedItems,
    required this.changes,
    required this.warnings,
    required this.createdAt,
  });

  final DaySchedule beforeSchedule;
  final DaySchedule afterSchedule;
  final List<ScheduleItem> preservedItems;
  final List<ScheduleChange> changes;
  final List<String> warnings;
  final DateTime createdAt;

  bool get hasChanges =>
      changes.any((change) => change.type.name != 'unchanged');
}
