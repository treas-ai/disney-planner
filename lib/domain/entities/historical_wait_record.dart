class HistoricalWaitRecord {
  const HistoricalWaitRecord({
    required this.parkId,
    required this.facilityId,
    required this.observedAt,
    required this.waitMinutes,
    required this.source,
    this.eventIds = const [],
    this.isHoliday = false,
    this.isExcluded = false,
    this.exclusionReason,
  }) : assert(waitMinutes >= 0);

  factory HistoricalWaitRecord.fromJson(Map<String, dynamic> json) {
    return HistoricalWaitRecord(
      parkId: json['parkId']?.toString() ?? '',
      facilityId: json['facilityId']?.toString() ?? '',
      observedAt: DateTime.parse(json['observedAt'].toString()),
      waitMinutes: (json['waitMinutes'] as num).round(),
      source: json['source']?.toString() ?? 'unknown',
      eventIds: (json['eventIds'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      isHoliday: json['isHoliday'] as bool? ?? false,
      isExcluded: json['isExcluded'] as bool? ?? false,
      exclusionReason: json['exclusionReason']?.toString(),
    );
  }

  final String parkId;
  final String facilityId;
  final DateTime observedAt;
  final int waitMinutes;
  final String source;
  final List<String> eventIds;
  final bool isHoliday;
  final bool isExcluded;
  final String? exclusionReason;

  Map<String, dynamic> toJson() => {
    'parkId': parkId,
    'facilityId': facilityId,
    'observedAt': observedAt.toIso8601String(),
    'waitMinutes': waitMinutes,
    'source': source,
    'eventIds': eventIds,
    'isHoliday': isHoliday,
    'isExcluded': isExcluded,
    'exclusionReason': exclusionReason,
  };
}
