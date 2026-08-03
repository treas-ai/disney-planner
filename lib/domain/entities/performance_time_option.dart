class PerformanceTimeOption {
  const PerformanceTimeOption({
    required this.id,
    required this.parkId,
    required this.facilityId,
    required this.date,
    required this.performanceIndex,
    required this.startTime,
  });

  factory PerformanceTimeOption.fromJson(Map<String, dynamic> json) {
    return PerformanceTimeOption(
      id: json['id'] as String? ?? '',
      parkId: json['parkId'] as String? ?? '',
      facilityId: json['facilityId'] as String? ?? '',
      date:
          DateTime.tryParse(json['date'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      performanceIndex: json['performanceIndex'] as int? ?? 0,
      startTime: json['startTime'] as String? ?? '',
    );
  }

  final String id;
  final String parkId;
  final String facilityId;
  final DateTime date;
  final int performanceIndex;
  final String startTime;

  String get displayLabel => '${performanceIndex + 1}回目 $startTime';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parkId': parkId,
      'facilityId': facilityId,
      'date': _dateKey(date),
      'performanceIndex': performanceIndex,
      'startTime': startTime,
    };
  }

  static String _dateKey(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
