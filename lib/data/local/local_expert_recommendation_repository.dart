import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/expert_recommendation_profile.dart';
import '../../domain/repositories/expert_recommendation_repository.dart';

class LocalExpertRecommendationRepository
    implements ExpertRecommendationRepository {
  const LocalExpertRecommendationRepository([this._assetBundle]);

  final AssetBundle? _assetBundle;

  AssetBundle get _bundle => _assetBundle ?? rootBundle;

  @override
  Future<List<ExpertRecommendationProfile>> loadProfiles({
    required String parkId,
  }) async {
    final source = await _bundle.loadString(
      'assets/master/expert_recommendations.json',
    );
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expert Recommendation master is invalid.');
    }
    final raw = decoded['profiles'];
    if (raw is! List) return const [];

    final prefix = parkId == 'tokyo_disneysea' ? 'tds_' : 'tdl_';
    return List<ExpertRecommendationProfile>.unmodifiable(
      raw
          .whereType<Map<String, dynamic>>()
          .map(ExpertRecommendationProfile.fromJson)
          .where((profile) => profile.facilityId.startsWith(prefix)),
    );
  }
}
