import 'package:disney_planner/data/repositories/local_greeting_wait_planning_repository.dart';
import 'package:disney_planner/domain/entities/crowd_factor_profile.dart';
import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/enums/crowd_factor_confidence.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/priority_level.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

Facility _greeting(String id, PriorityLevel priority) {
  return Facility(
    id: id,
    parkId: 'tokyo_disneyland',
    areaId: 'area',
    name: id,
    category: FacilityCategory.greeting,
    coordinate: const Coordinate(latitude: 0, longitude: 0),
    durationMinutes: 10,
    priority: priority,
  );
}

CrowdFactorProfile _factor(double value, String dimension) {
  return CrowdFactorProfile(
    parkId: 'tokyo_disneyland',
    facilityId: 'proxy_$value',
    factor: value,
    source: 'test',
    calculatedAt: DateTime.utc(2026, 9, 10),
    sampleStart: DateTime.utc(2026, 9, 1),
    sampleEnd: DateTime.utc(2026, 9, 10),
    sampleCount: 100,
    excludedCount: 0,
    confidence: CrowdFactorConfidence.high,
    methodVersion: 'test',
    dimensions: [dimension],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('混雑日はグリーティング基準値をGit混雑傾向で上方補正する', () async {
    final facility = _greeting(
      'tdl_toontown_mickey_house_meet_mickey',
      PriorityLevel.highest,
    );
    final result = await const LocalGreetingWaitPlanningRepository().load(
      parkId: 'tokyo_disneyland',
      targetDate: DateTime(2026, 10, 3),
      facilities: [facility],
      crowdFactors: [
        _factor(1.5, 'weekday:6'),
        _factor(1.5, 'season:autumn'),
      ],
    );

    final plan = result[facility.id]!;
    expect(plan.baseWaitMinutes, 40);
    expect(plan.parkCrowdMultiplier, 1.5);
    expect(plan.waitMinutes, 60);
    expect(plan.isCharacterBirthday, isFalse);
  });

  test('ミッキー誕生日は240分計画・480分級リスクとして扱う', () async {
    final facility = _greeting(
      'tdl_toontown_mickey_house_meet_mickey',
      PriorityLevel.highest,
    );
    final result = await const LocalGreetingWaitPlanningRepository().load(
      parkId: 'tokyo_disneyland',
      targetDate: DateTime(2026, 11, 18),
      facilities: [facility],
      crowdFactors: const [],
    );

    final plan = result[facility.id]!;
    expect(plan.isCharacterBirthday, isTrue);
    expect(plan.birthdayCharacterNames, contains('ミッキーマウス'));
    expect(plan.waitMinutes, 240);
    expect(plan.birthdayPlanningWaitMinutes, 240);
    expect(plan.birthdayExtremeRiskMinutes, 480);
    expect(plan.birthdayOpeningUrgencyBonus, 180);
  });
}
