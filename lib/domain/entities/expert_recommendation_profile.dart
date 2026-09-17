class ExpertRecommendationProfile {
  const ExpertRecommendationProfile({
    required this.facilityId,
    required this.experienceScore,
    required this.uniquenessScore,
    required this.scarcityScore,
    required this.note,
    this.validFrom,
    this.validUntil,
    this.spotlightFrom,
    this.spotlightUntil,
    this.spotlightScore = 0,
    this.spotlightReason,
  });

  factory ExpertRecommendationProfile.fromJson(Map<String, dynamic> json) =>
      ExpertRecommendationProfile(
        facilityId: json['facilityId'] as String? ?? '',
        experienceScore: (json['experienceScore'] as num?)?.toInt() ?? 50,
        uniquenessScore: (json['uniquenessScore'] as num?)?.toInt() ?? 50,
        scarcityScore: (json['scarcityScore'] as num?)?.toInt() ?? 0,
        note: json['note'] as String? ?? '',
        validFrom: _parseDate(json['validFrom']),
        validUntil: _parseDate(json['validUntil']),
        spotlightFrom: _parseDate(json['spotlightFrom']),
        spotlightUntil: _parseDate(json['spotlightUntil']),
        spotlightScore: (json['spotlightScore'] as num?)?.toInt() ?? 0,
        spotlightReason: json['spotlightReason'] as String?,
      );

  final String facilityId;
  final int experienceScore;
  final int uniquenessScore;
  final int scarcityScore;
  final String note;
  final DateTime? validFrom;
  final DateTime? validUntil;

  /// Optional, data-driven "why now?" signal. It can represent a seasonal
  /// event, a new show/parade, a reopening/renewal, or any future editorial
  /// reason without adding facility names to planner code.
  final DateTime? spotlightFrom;
  final DateTime? spotlightUntil;
  final int spotlightScore;
  final String? spotlightReason;

  bool appliesOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (validFrom != null && day.isBefore(validFrom!)) return false;
    if (validUntil != null && day.isAfter(validUntil!)) return false;
    return true;
  }

  bool spotlightAppliesOn(DateTime date) {
    if (spotlightScore <= 0) return false;
    final day = DateTime(date.year, date.month, date.day);
    if (spotlightFrom != null && day.isBefore(spotlightFrom!)) return false;
    if (spotlightUntil != null && day.isAfter(spotlightUntil!)) return false;
    return true;
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim());
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }
}
