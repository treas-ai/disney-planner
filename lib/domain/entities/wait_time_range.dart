class WaitTimeRange {
  const WaitTimeRange({
    required this.minMinutes,
    required this.typicalMinutes,
    required this.maxMinutes,
  }) : assert(minMinutes >= 0),
       assert(typicalMinutes >= minMinutes),
       assert(maxMinutes >= typicalMinutes);

  factory WaitTimeRange.fromJson(Map<String, dynamic> json) {
    return WaitTimeRange(
      minMinutes: json['minMinutes'] as int? ?? 0,
      typicalMinutes: json['typicalMinutes'] as int? ?? 0,
      maxMinutes: json['maxMinutes'] as int? ?? 0,
    );
  }

  final int minMinutes;
  final int typicalMinutes;
  final int maxMinutes;

  Map<String, dynamic> toJson() {
    return {
      'minMinutes': minMinutes,
      'typicalMinutes': typicalMinutes,
      'maxMinutes': maxMinutes,
    };
  }
}
