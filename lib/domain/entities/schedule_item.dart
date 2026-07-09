import '../enums/schedule_item_type.dart';

class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.title,
    required this.type,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.facilityId,
    this.reason,
    this.note,
  });

  final String id;
  final String title;
  final ScheduleItemType type;

  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  final String? facilityId;
  final String? reason;
  final String? note;

  String get startTimeLabel {
    return '${startHour.toString().padLeft(2, '0')}:'
        '${startMinute.toString().padLeft(2, '0')}';
  }

  String get endTimeLabel {
    return '${endHour.toString().padLeft(2, '0')}:'
        '${endMinute.toString().padLeft(2, '0')}';
  }

  String get timeRangeLabel {
    return '$startTimeLabel - $endTimeLabel';
  }
}