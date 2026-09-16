import '../enums/today_access_kind.dart';
import '../enums/today_access_status.dart';

class TodayAccessResult {
  const TodayAccessResult({
    required this.facilityId,
    required this.kind,
    required this.status,
    required this.updatedAt,
    this.time = '',
    this.note = '',
  });

  factory TodayAccessResult.fromJson(Map<String, dynamic> json) {
    return TodayAccessResult(
      facilityId: json['facilityId'] as String? ?? '',
      kind: TodayAccessKind.values.firstWhere(
        (value) => value.name == json['kind'],
        orElse: () => TodayAccessKind.attractionDpa,
      ),
      status: TodayAccessStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => TodayAccessStatus.unavailable,
      ),
      time: json['time'] as String? ?? '',
      note: json['note'] as String? ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String facilityId;
  final TodayAccessKind kind;
  final TodayAccessStatus status;
  final String time;
  final String note;
  final DateTime updatedAt;

  String get key => '${facilityId}_${kind.name}';
  bool get hasTime => time.trim().isNotEmpty;
  bool get fixesTime => status.fixesTime && hasTime;

  Map<String, dynamic> toJson() {
    return {
      'facilityId': facilityId,
      'kind': kind.name,
      'status': status.name,
      'time': time,
      'note': note,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
