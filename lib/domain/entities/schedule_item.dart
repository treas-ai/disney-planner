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
    this.estimatedWaitMinutes,
    this.experienceMinutes,
    this.waitEstimateSource,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      type: ScheduleItemType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => ScheduleItemType.facility,
      ),
      startHour: json['startHour'] as int? ?? 0,
      startMinute: json['startMinute'] as int? ?? 0,
      endHour: json['endHour'] as int? ?? 0,
      endMinute: json['endMinute'] as int? ?? 0,
      facilityId: json['facilityId'] as String?,
      reason: json['reason'] as String?,
      note: json['note'] as String?,
      estimatedWaitMinutes: json['estimatedWaitMinutes'] as int?,
      experienceMinutes: json['experienceMinutes'] as int?,
      waitEstimateSource: json['waitEstimateSource'] as String?,
    );
  }

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

  /// AI評価用の待ち時間内訳。既存保存データではnullを許容する。
  final int? estimatedWaitMinutes;
  final int? experienceMinutes;
  final String? waitEstimateSource;

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type.name,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'facilityId': facilityId,
      'reason': reason,
      'note': note,
      'estimatedWaitMinutes': estimatedWaitMinutes,
      'experienceMinutes': experienceMinutes,
      'waitEstimateSource': waitEstimateSource,
    };
  }
}
