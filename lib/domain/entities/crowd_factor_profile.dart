import '../enums/crowd_factor_confidence.dart';

class CrowdFactorProfile {
  const CrowdFactorProfile({
    required this.parkId,
    required this.facilityId,
    required this.factor,
    required this.source,
    required this.calculatedAt,
    required this.sampleStart,
    required this.sampleEnd,
    required this.sampleCount,
    required this.excludedCount,
    required this.confidence,
    required this.methodVersion,
    required this.dimensions,
  }) : assert(factor > 0);

  factory CrowdFactorProfile.fromJson(Map<String, dynamic> json) {
    return CrowdFactorProfile(
      parkId: json['parkId'] as String? ?? '',
      facilityId: json['facilityId'] as String? ?? '',
      factor: (json['factor'] as num?)?.toDouble() ?? 1,
      source: json['source'] as String? ?? '未設定',
      calculatedAt:
          DateTime.tryParse(json['calculatedAt'] as String? ?? '') ??
          DateTime(2000),
      sampleStart:
          DateTime.tryParse(json['sampleStart'] as String? ?? '') ??
          DateTime(2000),
      sampleEnd:
          DateTime.tryParse(json['sampleEnd'] as String? ?? '') ??
          DateTime(2000),
      sampleCount: json['sampleCount'] as int? ?? 0,
      excludedCount: json['excludedCount'] as int? ?? 0,
      confidence: CrowdFactorConfidence.fromName(json['confidence'] as String?),
      methodVersion: json['methodVersion'] as String? ?? '1.0',
      dimensions: List<String>.unmodifiable(
        (json['dimensions'] as List<dynamic>? ?? const []).whereType<String>(),
      ),
    );
  }

  final String parkId;
  final String facilityId;
  final double factor;
  final String source;
  final DateTime calculatedAt;
  final DateTime sampleStart;
  final DateTime sampleEnd;
  final int sampleCount;
  final int excludedCount;
  final CrowdFactorConfidence confidence;
  final String methodVersion;
  final List<String> dimensions;

  Map<String, dynamic> toJson() {
    return {
      'parkId': parkId,
      'facilityId': facilityId,
      'factor': factor,
      'source': source,
      'calculatedAt': calculatedAt.toIso8601String(),
      'sampleStart': sampleStart.toIso8601String(),
      'sampleEnd': sampleEnd.toIso8601String(),
      'sampleCount': sampleCount,
      'excludedCount': excludedCount,
      'confidence': confidence.name,
      'methodVersion': methodVersion,
      'dimensions': dimensions,
    };
  }
}
