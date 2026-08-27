import '../entities/expert_recommendation_profile.dart';

abstract interface class ExpertRecommendationRepository {
  Future<List<ExpertRecommendationProfile>> loadProfiles({
    required String parkId,
  });
}
