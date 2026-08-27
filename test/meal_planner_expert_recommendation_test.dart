import 'package:disney_planner/domain/entities/expert_recommendation_profile.dart';
import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/services/meal_planner.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

Facility _restaurant(String id) => Facility(
      id: id,
      parkId: 'tokyo_disneysea',
      areaId: 'area',
      name: id,
      category: FacilityCategory.restaurant,
      coordinate: const Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 45,
    );

void main() {
  test('flexible meal slot prefers higher expert experience when user priority ties', () {
    final destinationDining = _restaurant('destination_dining');
    final convenienceDining = _restaurant('convenience_dining');
    final settings = TripSettings.initial().copyWith(
      parkId: 'tokyo_disneysea',
      visitDateIso: '2026-08-30T00:00:00.000',
      wantsBreakfast: false,
      wantsLunch: true,
      wantsDinner: false,
    );

    final plan = const MealPlanner().plan(
      settings: settings,
      facilities: [convenienceDining, destinationDining],
      preferences: [
        PlanPreference.initial(facilityId: convenienceDining.id),
        PlanPreference.initial(facilityId: destinationDining.id),
      ],
      expertProfiles: const [
        ExpertRecommendationProfile(
          facilityId: 'destination_dining',
          experienceScore: 97,
          uniquenessScore: 100,
          scarcityScore: 80,
          note: 'パークを代表する食体験',
        ),
        ExpertRecommendationProfile(
          facilityId: 'convenience_dining',
          experienceScore: 65,
          uniquenessScore: 55,
          scarcityScore: 10,
          note: '利便性重視',
        ),
      ],
      targetDate: DateTime(2026, 8, 30),
    );

    expect(plan.assignmentFor(MealSlot.lunch)?.facility.id, 'destination_dining');
    expect(plan.assignmentFor(MealSlot.lunch)?.reason, contains('Disney通おすすめ評価'));
  });
}
