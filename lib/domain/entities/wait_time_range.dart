class WaitTimeRange {
  const WaitTimeRange({
    required this.minMinutes,
    required this.typicalMinutes,
    required this.maxMinutes,
    this.sampleCount,
  }) : assert(minMinutes >= 0),
       assert(typicalMinutes >= minMinutes),
       assert(maxMinutes >= typicalMinutes),
       assert(sampleCount == null || sampleCount >= 0);

  factory WaitTimeRange.fromJson(Map<String, dynamic> json) {
    return WaitTimeRange(
      minMinutes: json['minMinutes'] as int? ?? 0,
      typicalMinutes: json['typicalMinutes'] as int? ?? 0,
      maxMinutes: json['maxMinutes'] as int? ?? 0,
      sampleCount: json['sampleCount'] as int?,
    );
  }

  final int minMinutes;
  final int typicalMinutes;
  final int maxMinutes;

  /// Number of usable historical observations in this exact time band.
  /// Null means a legacy profile generated before v7.4.8.
  final int? sampleCount;

  Map<String, dynamic> toJson() {
    return {
      'minMinutes': minMinutes,
      'typicalMinutes': typicalMinutes,
      'maxMinutes': maxMinutes,
      if (sampleCount != null) 'sampleCount': sampleCount,
    };
  }
}
