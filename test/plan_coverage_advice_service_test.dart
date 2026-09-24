import 'package:flutter_test/flutter_test.dart';
import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/plan_coverage_advice.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/services/plan_coverage_advice_service.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';

void main() {
  const service = PlanCoverageAdviceService();

  test('未採用施設を検出しDPA最少個数と救済段階を返す', () {
    final beauty = _facility('beauty', '美女と野獣', supportsDpa: true);
    final pooh = _facility('pooh', 'プーさん', supportsDpa: true);
    final thunder = _facility('thunder', 'ビッグサンダー', supportsDpa: true);

    final advice = service.build(
      desiredFacilities: [beauty, pooh, thunder],
      currentScheduledFacilityIds: {'pooh', 'thunder'},
      currentScheduledDesiredCount: 2,
      scenarios: const [
        PlanCoverageScenario(
          dpaCount: 0,
          scheduledFacilityIds: {'pooh', 'thunder'},
          scheduledDesiredCount: 2,
          selectedDpaFacilityIds: [],
        ),
        PlanCoverageScenario(
          dpaCount: 1,
          scheduledFacilityIds: {'beauty', 'pooh', 'thunder'},
          scheduledDesiredCount: 3,
          selectedDpaFacilityIds: ['beauty'],
        ),
      ],
      orderedDpaMetrics: const [
        DpaOrderMetric(facilityId: 'beauty', estimatedSavedMinutes: 55),
      ],
    );

    expect(advice.currentScheduledCount, 2);
    expect(advice.minimumDpaCountForAll, 1);
    expect(advice.unmetFacilities, hasLength(1));
    expect(advice.unmetFacilities.single.facilityId, 'beauty');
    expect(advice.unmetFacilities.single.firstRescuedAtDpaCount, 1);
    expect(advice.dpaAcquisitionOrder.single.name, '美女と野獣');
  });

  test('DPAを増やしても未採用なら全件達成と誤表示しない', () {
    final beauty = _facility('beauty', '美女と野獣', supportsDpa: true);
    final greeting = _facility(
      'mickey',
      'ミッキーの家',
      category: FacilityCategory.greeting,
    );

    final advice = service.build(
      desiredFacilities: [beauty, greeting],
      currentScheduledFacilityIds: {'beauty'},
      currentScheduledDesiredCount: 1,
      scenarios: const [
        PlanCoverageScenario(
          dpaCount: 0,
          scheduledFacilityIds: {'beauty'},
          scheduledDesiredCount: 1,
          selectedDpaFacilityIds: [],
        ),
        PlanCoverageScenario(
          dpaCount: 1,
          scheduledFacilityIds: {'beauty'},
          scheduledDesiredCount: 1,
          selectedDpaFacilityIds: ['beauty'],
        ),
      ],
      orderedDpaMetrics: const [
        DpaOrderMetric(facilityId: 'beauty', estimatedSavedMinutes: 40),
      ],
    );

    expect(advice.minimumDpaCountForAll, isNull);
    expect(advice.unmetFacilities.single.facilityId, 'mickey');
    expect(advice.unmetFacilities.single.firstRescuedAtDpaCount, isNull);
  });
  test('同一施設を2回希望した場合はDPA 1個で1回しか入らなくても全件達成にしない', () {
    final beauty = _facility('beauty', '美女と野獣', supportsDpa: true);
    final pooh = _facility('pooh', 'プーさん', supportsDpa: true);

    final advice = service.build(
      desiredFacilities: [beauty, beauty, pooh],
      currentScheduledFacilityIds: {'beauty', 'pooh'},
      currentScheduledDesiredCount: 2,
      scenarios: const [
        PlanCoverageScenario(
          dpaCount: 0,
          scheduledFacilityIds: {'beauty', 'pooh'},
          scheduledDesiredCount: 2,
          selectedDpaFacilityIds: [],
        ),
        PlanCoverageScenario(
          dpaCount: 1,
          scheduledFacilityIds: {'beauty', 'pooh'},
          scheduledDesiredCount: 2,
          selectedDpaFacilityIds: ['beauty'],
        ),
      ],
      orderedDpaMetrics: const [
        DpaOrderMetric(facilityId: 'beauty', estimatedSavedMinutes: 60),
      ],
    );

    expect(advice.totalDesiredCount, 3);
    expect(advice.currentScheduledCount, 2);
    expect(advice.minimumDpaCountForAll, isNull);
  });

  test('同一施設の希望回数が一部未達なら未採用一覧にも残す', () {
    final baymax = _facility('baymax', 'ベイマックス', supportsDpa: true);

    final advice = service.build(
      desiredFacilities: [baymax, baymax],
      currentScheduledFacilityIds: {'baymax'},
      currentScheduledFacilityCounts: const {'baymax': 1},
      currentScheduledDesiredCount: 1,
      scenarios: const [
        PlanCoverageScenario(
          dpaCount: 0,
          scheduledFacilityIds: {'baymax'},
          scheduledDesiredCount: 1,
          selectedDpaFacilityIds: [],
        ),
      ],
      orderedDpaMetrics: const [],
    );

    expect(advice.unmetFacilities, hasLength(1));
    expect(advice.unmetFacilities.single.facilityId, 'baymax');
    expect(advice.unmetFacilities.single.reason, contains('2回希望のうち1回達成、あと1回'));
  });

}

Facility _facility(
  String id,
  String name, {
  bool supportsDpa = false,
  FacilityCategory category = FacilityCategory.attraction,
}) {
  return Facility(
    id: id,
    parkId: 'tokyo_disneyland',
    areaId: 'area',
    name: name,
    category: category,
    coordinate: const Coordinate(latitude: 0, longitude: 0),
    supportsDpa: supportsDpa,
    durationMinutes: 10,
  );
}
