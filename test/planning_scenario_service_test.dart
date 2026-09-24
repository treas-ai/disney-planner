import 'package:flutter_test/flutter_test.dart';
import 'package:disney_planner/domain/entities/plan_coverage_advice.dart';
import 'package:disney_planner/domain/entities/planning_scenario.dart';
import 'package:disney_planner/domain/services/planning_scenario_service.dart';

void main() {
  test('Vacation Package comparison can represent benefit without invented total price', () {
    const scenario = PlanningScenario(
      kind: PlanningScenarioKind.vacationPackage,
      scheduledDesiredCount: 10,
      totalDesiredCount: 11,
      costDataAvailable: false,
      extraCostYen: null,
      totalWaitMinutes: 120,
      totalFreeMinutes: 90,
    );

    expect(scenario.kind, PlanningScenarioKind.vacationPackage);
    expect(scenario.costDataAvailable, isFalse);
    expect(scenario.extraCostYen, isNull);
    expect(scenario.unmetDesiredCount, 1);
  });

  test('keeps DPA as execution scenario and does not invent prices', () {
    const advice = PlanCoverageAdvice(
      totalDesiredCount: 11,
      currentScheduledCount: 9,
      unmetFacilities: <UnmetPlanFacilityAdvice>[],
      scenarios: <PlanCoverageScenario>[
        PlanCoverageScenario(
          dpaCount: 0,
          scheduledFacilityIds: <String>{'a'},
          scheduledDesiredCount: 9,
          selectedDpaFacilityIds: <String>[],
        ),
        PlanCoverageScenario(
          dpaCount: 1,
          scheduledFacilityIds: <String>{'a', 'b'},
          scheduledDesiredCount: 10,
          selectedDpaFacilityIds: <String>['b'],
        ),
      ],
      dpaAcquisitionOrder: <DpaAcquisitionAdvice>[],
      simulatedMaxDpaCount: 1,
    );

    final result = const PlanningScenarioService().fromCoverageAdvice(advice);

    expect(result.scenarios, hasLength(2));
    expect(result.scenarios.first.kind, PlanningScenarioKind.noExtraCost);
    expect(result.scenarios.first.scheduledDesiredCount, 9);
    expect(result.scenarios.last.kind, PlanningScenarioKind.dpa);
    expect(result.scenarios.last.dpaCount, 1);
    expect(result.scenarios.last.scheduledDesiredCount, 10);
    expect(result.scenarios.last.selectedDpaFacilityIds, <String>['b']);
    expect(result.scenarios.last.extraCostYen, isNull);
    expect(result.costComparisonReady, isFalse);
  });

  test('occurrence coverage is preserved instead of facility-id coverage', () {
    const scenario = PlanningScenario(
      kind: PlanningScenarioKind.noExtraCost,
      scheduledDesiredCount: 9,
      totalDesiredCount: 11,
    );
    expect(scenario.unmetDesiredCount, 2);
    expect(scenario.fulfillsAll, isFalse);
  });
  _dev45PriceCoverage();
  _dev46BudgetSelection();
}

// dev.45: date-valid official DPA prices are multiplied by party size.
void _dev45PriceCoverage() {
  test('prices DPA scenario for the whole party when visit date is known', () {
    const advice = PlanCoverageAdvice(
      totalDesiredCount: 11,
      currentScheduledCount: 9,
      unmetFacilities: <UnmetPlanFacilityAdvice>[],
      scenarios: <PlanCoverageScenario>[
        PlanCoverageScenario(
          dpaCount: 1,
          scheduledFacilityIds: <String>{'baymax'},
          scheduledDesiredCount: 10,
          selectedDpaFacilityIds: <String>['tdl_tomorrowland_baymax_happy_ride'],
          totalWaitMinutes: 300,
          totalFreeMinutes: 90,
        ),
      ],
      dpaAcquisitionOrder: <DpaAcquisitionAdvice>[],
      simulatedMaxDpaCount: 1,
    );
    final result = const PlanningScenarioService().fromCoverageAdvice(
      advice,
      visitDate: DateTime(2026, 9, 26),
      numberOfPeople: 2,
    );
    expect(result.costComparisonReady, isTrue);
    expect(result.scenarios.single.extraCostYen, 3000);
    expect(result.scenarios.single.totalWaitMinutes, 300);
    expect(result.scenarios.single.totalFreeMinutes, 90);
  });
}


void _dev46BudgetSelection() {
  const service = PlanningScenarioService();
  const baseline = PlanningScenario(
    kind: PlanningScenarioKind.noExtraCost,
    scheduledDesiredCount: 9,
    totalDesiredCount: 11,
    extraCostYen: 0,
    costDataAvailable: true,
    totalWaitMinutes: 335,
  );
  const dpaOne = PlanningScenario(
    kind: PlanningScenarioKind.dpa,
    scheduledDesiredCount: 10,
    totalDesiredCount: 11,
    dpaCount: 1,
    selectedDpaFacilityIds: <String>['beauty'],
    extraCostYen: 2500,
    costDataAvailable: true,
    totalWaitMinutes: 315,
  );
  const dpaTwo = PlanningScenario(
    kind: PlanningScenarioKind.dpa,
    scheduledDesiredCount: 11,
    totalDesiredCount: 11,
    dpaCount: 2,
    selectedDpaFacilityIds: <String>['beauty', 'baymax'],
    extraCostYen: 4000,
    costDataAvailable: true,
    totalWaitMinutes: 280,
  );
  const set = PlanningScenarioSet(
    scenarios: <PlanningScenario>[baseline, dpaOne, dpaTwo],
    costComparisonReady: true,
  );

  test('no-extra-cost mode keeps baseline', () {
    expect(
      service.recommend(
        set,
        budgetMode: PlanningBudgetMode.noExtraCost,
        maxExtraBudgetYen: 5000,
      ),
      same(baseline),
    );
  });

  test('low-cost mode picks cheapest scenario that improves coverage', () {
    expect(
      service.recommend(
        set,
        budgetMode: PlanningBudgetMode.lowCost,
        maxExtraBudgetYen: 5000,
      )?.dpaCount,
      1,
    );
  });

  test('budget cap picks best coverage inside the cap', () {
    expect(
      service.recommend(
        set,
        budgetMode: PlanningBudgetMode.maxExtraBudget,
        maxExtraBudgetYen: 3000,
      )?.dpaCount,
      1,
    );
  });

  test('fulfillment-first picks highest coverage then lower wait', () {
    expect(
      service.recommend(
        set,
        budgetMode: PlanningBudgetMode.fulfillmentFirst,
        maxExtraBudgetYen: 0,
      )?.dpaCount,
      2,
    );
  });
}
