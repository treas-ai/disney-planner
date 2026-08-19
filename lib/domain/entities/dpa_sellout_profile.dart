class DpaSelloutProfile {
  const DpaSelloutProfile({
    required this.facilityId,
    required this.parkId,
    required this.averageSelloutTime,
    required this.sampleCount,
    required this.source,
    required this.checkedAt,
  });

  factory DpaSelloutProfile.fromJson(Map<String, dynamic> json) {
    return DpaSelloutProfile(
      facilityId: json['facilityId'] as String? ?? '',
      parkId: json['parkId'] as String? ?? '',
      averageSelloutTime: json['averageSelloutTime'] as String? ?? '',
      sampleCount: json['sampleCount'] as int? ?? 0,
      source: json['source'] as String? ?? '未設定',
      checkedAt:
          DateTime.tryParse(json['checkedAt'] as String? ?? '') ??
          DateTime(2000),
    );
  }

  final String facilityId;
  final String parkId;
  final String averageSelloutTime;
  final int sampleCount;
  final String source;
  final DateTime checkedAt;

  int? get averageSelloutMinuteOfDay {
    final parts = averageSelloutTime.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }
}
