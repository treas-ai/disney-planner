import 'package:disney_planner/domain/entities/expert_recommendation_profile.dart';
import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/services/disney_expert_recommendation_service.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

Facility _facility(String id, {String? rideType}) => Facility(
      id: id,
      parkId: 'tokyo_disneysea',
      areaId: 'area',
      name: id,
      category: FacilityCategory.attraction,
      coordinate: const Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 10,
      rideType: rideType,
    );

void main() {
  const service = DisneyExpertRecommendationService();

  test('curated Disney expert value can outweigh generic medium priority', () {
    final major = _facility('major');
    final minor = _facility('minor');
    const profiles = [
      ExpertRecommendationProfile(
        facilityId: 'major',
        experienceScore: 100,
        uniquenessScore: 100,
        scarcityScore: 70,
        note: '代表体験',
      ),
      ExpertRecommendationProfile(
        facilityId: 'minor',
        experienceScore: 50,
        uniquenessScore: 45,
        scarcityScore: 5,
        note: '後回し可能',
      ),
    ];

    final majorScore = service.evaluate(
      facility: major,
      targetDate: DateTime(2026, 8, 30),
      profiles: profiles,
    );
    final minorScore = service.evaluate(
      facility: minor,
      targetDate: DateTime(2026, 8, 30),
      profiles: profiles,
    );

    expect(majorScore.score, greaterThan(minorScore.score));
    expect(majorScore.reason, contains('代表体験'));
  });

  test('expired seasonal profile is not applied outside its valid date', () {
    final facility = _facility('seasonal');
    final profiles = [
      ExpertRecommendationProfile(
        facilityId: 'seasonal',
        experienceScore: 100,
        uniquenessScore: 100,
        scarcityScore: 100,
        note: '期間限定',
        validFrom: DateTime(2026, 7, 2),
        validUntil: DateTime(2026, 9, 14),
      ),
    ];

    final during = service.evaluate(
      facility: facility,
      targetDate: DateTime(2026, 8, 29),
      profiles: profiles,
    );
    final after = service.evaluate(
      facility: facility,
      targetDate: DateTime(2026, 9, 15),
      profiles: profiles,
    );

    expect(during.score, greaterThan(after.score));
  });

  test('transport experience is not recommended as a destination by itself', () {
    final ride = _facility('ride');
    final transport = _facility('transport', rideType: 'transportation');

    final rideScore = service.evaluate(
      facility: ride,
      targetDate: DateTime(2026, 8, 30),
      profiles: const [],
    );
    final transportScore = service.evaluate(
      facility: transport,
      targetDate: DateTime(2026, 8, 30),
      profiles: const [],
    );

    expect(transportScore.score, lessThan(rideScore.score));
  });
}
