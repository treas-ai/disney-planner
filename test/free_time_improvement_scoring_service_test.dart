import 'package:disney_planner/domain/services/free_time_improvement_scoring_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = FreeTimeImprovementScoringService();

  test('やりたいこと登録済み施設を未登録の高優先度グリーティングより優先する', () {
    final wishlistedAttraction = service.scoreFacility(
      priorityValue: 3,
      plannedDurationMinutes: 45,
      movementInMinutes: 15,
      movementOutMinutes: 15,
      fitSlackMinutes: 60,
      isWishlisted: true,
      samePreviousArea: false,
      sameNextArea: false,
      isGreeting: false,
    );
    final unselectedGreeting = service.scoreFacility(
      priorityValue: 5,
      plannedDurationMinutes: 50,
      movementInMinutes: 15,
      movementOutMinutes: 15,
      fitSlackMinutes: 60,
      isWishlisted: false,
      samePreviousArea: false,
      sameNextArea: false,
      isGreeting: true,
    );

    expect(wishlistedAttraction, greaterThan(unselectedGreeting));
  });

  test('未登録グリーティングにはカテゴリ由来の優遇を与えない', () {
    final greeting = service.scoreFacility(
      priorityValue: 4,
      plannedDurationMinutes: 40,
      movementInMinutes: 10,
      movementOutMinutes: 10,
      fitSlackMinutes: 30,
      isWishlisted: false,
      samePreviousArea: false,
      sameNextArea: false,
      isGreeting: true,
    );
    final attraction = service.scoreFacility(
      priorityValue: 4,
      plannedDurationMinutes: 40,
      movementInMinutes: 10,
      movementOutMinutes: 10,
      fitSlackMinutes: 30,
      isWishlisted: false,
      samePreviousArea: false,
      sameNextArea: false,
      isGreeting: false,
    );

    expect(greeting, lessThan(attraction));
  });

  test('同じ候補ならユーザーが設定した優先度が高いほど上位になる', () {
    final high = service.scoreFacility(
      priorityValue: 5,
      plannedDurationMinutes: 40,
      movementInMinutes: 10,
      movementOutMinutes: 10,
      fitSlackMinutes: 30,
      isWishlisted: true,
      samePreviousArea: false,
      sameNextArea: false,
      isGreeting: false,
    );
    final low = service.scoreFacility(
      priorityValue: 2,
      plannedDurationMinutes: 40,
      movementInMinutes: 10,
      movementOutMinutes: 10,
      fitSlackMinutes: 30,
      isWishlisted: true,
      samePreviousArea: false,
      sameNextArea: false,
      isGreeting: false,
    );

    expect(high, greaterThan(low));
  });

  test('未登録の最高優先度施設でも登録済み低優先度候補を上回らない', () {
    final wishlistedLow = service.scoreFacility(
      priorityValue: 2,
      plannedDurationMinutes: 45,
      movementInMinutes: 15,
      movementOutMinutes: 15,
      fitSlackMinutes: 60,
      isWishlisted: true,
      samePreviousArea: false,
      sameNextArea: false,
      isGreeting: false,
    );
    final unselectedHighest = service.scoreFacility(
      priorityValue: 5,
      plannedDurationMinutes: 30,
      movementInMinutes: 5,
      movementOutMinutes: 5,
      fitSlackMinutes: 20,
      isWishlisted: false,
      samePreviousArea: true,
      sameNextArea: true,
      isGreeting: false,
    );

    expect(wishlistedLow, greaterThan(unselectedHighest));
  });


  test('長い空き時間では短い低価値施設より高体験価値の候補を優先する', () {
    final shortLowValue = service.scoreFacility(
      priorityValue: 2,
      plannedDurationMinutes: 11,
      movementInMinutes: 15,
      movementOutMinutes: 15,
      fitSlackMinutes: 115,
      isWishlisted: false,
      samePreviousArea: false,
      sameNextArea: false,
      isGreeting: false,
      expertScore: 35,
      estimatedWaitMinutes: 5,
      gapMinutes: 146,
    );
    final meaningfulExperience = service.scoreFacility(
      priorityValue: 3,
      plannedDurationMinutes: 25,
      movementInMinutes: 15,
      movementOutMinutes: 15,
      fitSlackMinutes: 91,
      isWishlisted: false,
      samePreviousArea: false,
      sameNextArea: false,
      isGreeting: false,
      expertScore: 70,
      estimatedWaitMinutes: 10,
      gapMinutes: 146,
    );

    expect(meaningfulExperience, greaterThan(shortLowValue));
  });

  test('新しいおすすめでは余白が大きすぎる候補を軽く減点する', () {
    final fillsGapBetter = service.scoreFacility(
      priorityValue: 3,
      plannedDurationMinutes: 55,
      movementInMinutes: 10,
      movementOutMinutes: 10,
      fitSlackMinutes: 71,
      isWishlisted: false,
      samePreviousArea: false,
      sameNextArea: false,
      isGreeting: false,
      expertScore: 65,
      estimatedWaitMinutes: 20,
      gapMinutes: 146,
    );
    final leavesHugeGap = service.scoreFacility(
      priorityValue: 3,
      plannedDurationMinutes: 15,
      movementInMinutes: 10,
      movementOutMinutes: 10,
      fitSlackMinutes: 111,
      isWishlisted: false,
      samePreviousArea: false,
      sameNextArea: false,
      isGreeting: false,
      expertScore: 65,
      estimatedWaitMinutes: 5,
      gapMinutes: 146,
    );

    expect(fillsGapBetter, greaterThan(leavesHugeGap));
  });

}
