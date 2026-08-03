import '../enums/schedule_change_type.dart';
import 'schedule_item.dart';

class ScheduleChange {
  const ScheduleChange({
    required this.key,
    required this.type,
    required this.reason,
    this.beforeItem,
    this.afterItem,
  });

  final String key;
  final ScheduleChangeType type;
  final String reason;
  final ScheduleItem? beforeItem;
  final ScheduleItem? afterItem;

  String get title => afterItem?.title ?? beforeItem?.title ?? key;
}
