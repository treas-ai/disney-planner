import '../enums/activity_history_type.dart';
import '../enums/history_data_quality.dart';
import '../enums/history_data_source.dart';

class ActivityHistoryRecord {
  const ActivityHistoryRecord({
    required this.id,
    required this.type,
    required this.parkId,
    required this.recordedAt,
    required this.source,
    required this.quality,
    this.facilityId,
    this.fromFacilityId,
    this.toFacilityId,
    this.waitMinutes,
    this.durationMinutes,
    this.startedAt,
    this.endedAt,
    this.weatherName,
    this.crowdLevel,
    this.note = '',
  });

  factory ActivityHistoryRecord.waitTime({
    required String id,
    required String parkId,
    required String facilityId,
    required int waitMinutes,
    required DateTime recordedAt,
    HistoryDataSource source = HistoryDataSource.manual,
    HistoryDataQuality quality = HistoryDataQuality.high,
    String? weatherName,
    int? crowdLevel,
    String note = '',
  }) {
    return ActivityHistoryRecord(
      id: id,
      type: ActivityHistoryType.waitTime,
      parkId: parkId,
      facilityId: facilityId,
      waitMinutes: waitMinutes,
      recordedAt: recordedAt,
      source: source,
      quality: quality,
      weatherName: weatherName,
      crowdLevel: crowdLevel,
      note: note,
    );
  }

  factory ActivityHistoryRecord.fromJson(Map<String, dynamic> json) {
    return ActivityHistoryRecord(
      id: json['id'] as String? ?? '',
      type: ActivityHistoryType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => ActivityHistoryType.waitTime,
      ),
      parkId: json['parkId'] as String? ?? '',
      facilityId: json['facilityId'] as String?,
      fromFacilityId: json['fromFacilityId'] as String?,
      toFacilityId: json['toFacilityId'] as String?,
      waitMinutes: json['waitMinutes'] as int?,
      durationMinutes: json['durationMinutes'] as int?,
      recordedAt:
          DateTime.tryParse(json['recordedAt'] as String? ?? '') ??
          DateTime.now(),
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
      endedAt: DateTime.tryParse(json['endedAt'] as String? ?? ''),
      source: HistoryDataSource.values.firstWhere(
        (value) => value.name == json['source'],
        orElse: () => HistoryDataSource.manual,
      ),
      quality: HistoryDataQuality.values.firstWhere(
        (value) => value.name == json['quality'],
        orElse: () => HistoryDataQuality.medium,
      ),
      weatherName: json['weatherName'] as String?,
      crowdLevel: json['crowdLevel'] as int?,
      note: json['note'] as String? ?? '',
    );
  }

  final String id;
  final ActivityHistoryType type;
  final String parkId;
  final String? facilityId;
  final String? fromFacilityId;
  final String? toFacilityId;
  final int? waitMinutes;
  final int? durationMinutes;
  final DateTime recordedAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final HistoryDataSource source;
  final HistoryDataQuality quality;
  final String? weatherName;
  final int? crowdLevel;
  final String note;

  bool get isValid {
    if (id.trim().isEmpty || parkId.trim().isEmpty) {
      return false;
    }

    return switch (type) {
      ActivityHistoryType.waitTime =>
        facilityId?.trim().isNotEmpty == true &&
            waitMinutes != null &&
            waitMinutes! >= 0,
      ActivityHistoryType.movement =>
        fromFacilityId?.trim().isNotEmpty == true &&
            toFacilityId?.trim().isNotEmpty == true &&
            durationMinutes != null &&
            durationMinutes! >= 0,
      ActivityHistoryType.facilityUse ||
      ActivityHistoryType.meal ||
      ActivityHistoryType.show ||
      ActivityHistoryType.shopping => facilityId?.trim().isNotEmpty == true,
    };
  }

  bool get isTrainingEligible {
    return isValid &&
        source != HistoryDataSource.predicted &&
        quality != HistoryDataQuality.low;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'parkId': parkId,
      'facilityId': facilityId,
      'fromFacilityId': fromFacilityId,
      'toFacilityId': toFacilityId,
      'waitMinutes': waitMinutes,
      'durationMinutes': durationMinutes,
      'recordedAt': recordedAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'source': source.name,
      'quality': quality.name,
      'weatherName': weatherName,
      'crowdLevel': crowdLevel,
      'note': note,
    };
  }
}
