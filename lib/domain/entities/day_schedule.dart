import 'schedule_item.dart';

class DaySchedule {
  const DaySchedule({
    required this.id,
    required this.parkId,
    required this.items,
    required this.createdAt,
  });

  final String id;
  final String parkId;
  final List<ScheduleItem> items;
  final DateTime createdAt;
}