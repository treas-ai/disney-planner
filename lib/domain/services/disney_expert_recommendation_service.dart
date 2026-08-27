import '../entities/expert_recommendation_profile.dart';
import '../entities/facility.dart';
import '../entities/plan_preference.dart';
import '../entities/time_band_wait_profile.dart';
import '../enums/facility_category.dart';
import '../enums/wait_time_band.dart';

class DisneyExpertRecommendationEvaluation {
  const DisneyExpertRecommendationEvaluation({
    required this.score,
    required this.experienceScore,
    required this.uniquenessScore,
    required this.scarcityScore,
    required this.dayDifficultyMinutes,
    required this.reason,
  });

  final double score;
  final int experienceScore;
  final int uniquenessScore;
  final int scarcityScore;
  final int dayDifficultyMinutes;
  final String reason;
}

class DisneyExpertRecommendationService {
  const DisneyExpertRecommendationService();

  DisneyExpertRecommendationEvaluation evaluate({
    required Facility facility,
    required DateTime targetDate,
    required List<ExpertRecommendationProfile> profiles,
    PlanPreference? preference,
    List<TimeBandWaitProfile> waitProfiles = const [],
  }) {
    final profile = _profile(
      facilityId: facility.id,
      targetDate: targetDate,
      profiles: profiles,
    );
    final experience =
        profile?.experienceScore ?? _fallbackExperience(facility);
    final uniqueness =
        profile?.uniquenessScore ?? _fallbackUniqueness(facility);
    final scarcity = profile?.scarcityScore ?? _fallbackScarcity(facility);
    final difficulty = _difficulty(facility, waitProfiles);
    final priority = preference?.priority.value ?? facility.priority.value;

    var score = experience * 0.44;
    score += uniqueness * 0.24;
    score += scarcity * 0.18;
    score += difficulty.clamp(0, 120) * 0.10;
    score += priority * 3.0;

    if (facility.isSeasonal) score += 8;
    if (facility.isShowRestaurant) score += 10;
    if (facility.requiresEntryRequest) score += 4;
    if (facility.requiresReservation || facility.reservationRequired) {
      score += 3;
    }

    // 移動型施設は「目的地体験」ではなく、次の行動まで含めたルート価値で
    // 評価する。乗車地点/降車地点による移動メリットはScheduleEngine側で扱う。
    if (facility.rideType?.trim().toLowerCase() == 'transportation') {
      score -= 18;
    }

    final note = profile?.note.trim();
    final reasons = <String>[
      '体験価値$experience/100',
      'そのパークならでは度$uniqueness/100',
      '希少性$scarcity/100',
      if (difficulty > 0) '通常待機難易度 最大約$difficulty分',
      if (facility.isSeasonal) '期間限定',
      if (facility.isShowRestaurant) '食事＋ショー体験',
      if (note != null && note.isNotEmpty) note,
    ];

    return DisneyExpertRecommendationEvaluation(
      score: score,
      experienceScore: experience,
      uniquenessScore: uniqueness,
      scarcityScore: scarcity,
      dayDifficultyMinutes: difficulty,
      reason: reasons.join('、'),
    );
  }

  ExpertRecommendationProfile? _profile({
    required String facilityId,
    required DateTime targetDate,
    required List<ExpertRecommendationProfile> profiles,
  }) {
    for (final profile in profiles) {
      if (profile.facilityId == facilityId && profile.appliesOn(targetDate)) {
        return profile;
      }
    }
    return null;
  }

  int _fallbackExperience(Facility facility) {
    final base = switch (facility.category) {
      FacilityCategory.show || FacilityCategory.parade => 64,
      FacilityCategory.attraction => 58,
      FacilityCategory.greeting => 56,
      FacilityCategory.restaurant => 52,
      _ => 45,
    };
    return (base + facility.priority.value * 6).clamp(0, 100).toInt();
  }

  int _fallbackUniqueness(Facility facility) {
    var value = 45;
    if (facility.isSeasonal) value += 20;
    if (facility.isShowRestaurant) value += 22;
    if (facility.category == FacilityCategory.show ||
        facility.category == FacilityCategory.parade) {
      value += 10;
    }
    if (facility.rideType?.trim().toLowerCase() == 'transportation') {
      value -= 10;
    }
    return value.clamp(0, 100).toInt();
  }

  int _fallbackScarcity(Facility facility) {
    var value = 10;
    if (facility.isSeasonal) value += 30;
    if (facility.requiresEntryRequest) value += 20;
    if (facility.requiresReservation || facility.reservationRequired) {
      value += 15;
    }
    if (facility.isShowRestaurant) value += 15;
    return value.clamp(0, 100).toInt();
  }

  int _difficulty(
    Facility facility,
    List<TimeBandWaitProfile> profiles,
  ) {
    if (facility.category != FacilityCategory.attraction) return 0;

    for (final profile in profiles) {
      if (profile.facilityId != facility.id ||
          profile.parkId != facility.parkId) {
        continue;
      }
      var maximum = 0;
      for (final band in WaitTimeBand.values) {
        final range = profile.rangeFor(band);
        if (range == null || range.typicalMinutes <= 0) continue;
        if (range.sampleCount != null && range.sampleCount! < 3) continue;
        if (range.typicalMinutes > maximum) maximum = range.typicalMinutes;
      }
      return maximum;
    }
    return 0;
  }
}
