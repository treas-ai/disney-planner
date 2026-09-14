import '../enums/facility_access_method.dart';
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
    this.accessMethod,
    this.usesVacationPackageUnlimited = false,
    this.standbyWaitMinutes,
    this.priorityAccessBufferMinutes,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    final source = json['waitEstimateSource'] as String?;
    final legacyEstimatedWait = json['estimatedWaitMinutes'] as int?;
    final accessMethodName = json['accessMethod'] as String?;
    final accessMethod = accessMethodName == null
        ? null
        : FacilityAccessMethod.values.firstWhere(
            (method) => method.name == accessMethodName,
            orElse: () => FacilityAccessMethod.standby,
          );
    final legacyPriorityAccess = _looksLikePriorityAccessSource(source);
    final usesVacationPackageUnlimited =
        json['usesVacationPackageUnlimited'] as bool? ??
        _looksLikeVacationPackageSource(source);

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
      estimatedWaitMinutes: legacyEstimatedWait,
      experienceMinutes: json['experienceMinutes'] as int?,
      waitEstimateSource: source,
      accessMethod: accessMethod,
      usesVacationPackageUnlimited: usesVacationPackageUnlimited,
      standbyWaitMinutes: json['standbyWaitMinutes'] as int? ??
          (legacyPriorityAccess ? null : legacyEstimatedWait),
      priorityAccessBufferMinutes:
          json['priorityAccessBufferMinutes'] as int? ??
          (legacyPriorityAccess ? legacyEstimatedWait : null),
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

  /// Scheduled access method. Null is allowed for legacy/non-facility items.
  final FacilityAccessMethod? accessMethod;

  /// Vacation Package unlimited-attraction access is separate from standby.
  final bool usesVacationPackageUnlimited;

  /// Normal standby queue estimate. Never stores a priority-entry buffer.
  final int? standbyWaitMinutes;

  /// DPA/PP/Standby Pass/Vacation Package entry buffer.
  final int? priorityAccessBufferMinutes;

  bool get usesPriorityAccessPlanning =>
      usesVacationPackageUnlimited || priorityAccessBufferMinutes != null;

  /// Backward-compatible effective planning queue/buffer minutes.
  int? get effectiveQueueMinutes =>
      priorityAccessBufferMinutes ?? standbyWaitMinutes ?? estimatedWaitMinutes;

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
      'accessMethod': accessMethod?.name,
      'usesVacationPackageUnlimited': usesVacationPackageUnlimited,
      'standbyWaitMinutes': standbyWaitMinutes,
      'priorityAccessBufferMinutes': priorityAccessBufferMinutes,
    };
  }
}


bool _looksLikePriorityAccessSource(String? source) {
  final value = source?.trim() ?? '';
  return value.contains('バケーションパッケージ乗り放題') ||
      value.contains('バケパ乗り放題') ||
      value.contains('優先入口') ||
      value.contains('DPA') ||
      value.contains('プライオリティ') ||
      value.contains('パス利用時');
}

bool _looksLikeVacationPackageSource(String? source) {
  final value = source?.trim() ?? '';
  return value.contains('バケーションパッケージ乗り放題') ||
      value.contains('バケパ乗り放題');
}
