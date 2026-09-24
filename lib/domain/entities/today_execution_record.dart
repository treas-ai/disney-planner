enum TodayExecutionStatus { completed, skipped }

class TodayExecutionRecord {
  const TodayExecutionRecord({
    required this.scheduleItemId,
    required this.status,
    required this.recordedAt,
    this.facilityId,
  });

  factory TodayExecutionRecord.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String? ?? '';
    return TodayExecutionRecord(
      scheduleItemId: json['scheduleItemId'] as String? ?? '',
      facilityId: json['facilityId'] as String?,
      status: TodayExecutionStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => TodayExecutionStatus.completed,
      ),
      recordedAt: DateTime.tryParse(json['recordedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String scheduleItemId;
  final String? facilityId;
  final TodayExecutionStatus status;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() => {
        'scheduleItemId': scheduleItemId,
        'facilityId': facilityId,
        'status': status.name,
        'recordedAt': recordedAt.toIso8601String(),
      };
}
