import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/greeting_wait_planning_value.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/priority_level.dart';
import 'package:disney_planner/domain/services/schedule_engine.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

Facility _facility(
  String id, {
  required FacilityCategory category,
  PriorityLevel priority = PriorityLevel.medium,
}) {
  return Facility(
    id: id,
    parkId: 'tokyo_disneyland',
    areaId: 'area_a',
    name: id,
    category: category,
    coordinate: const Coordinate(latitude: 0, longitude: 0),
    durationMinutes: 10,
    priority: priority,
  );
}

TripSettings _settings() {
  return TripSettings.initial().copyWith(
    parkId: 'tokyo_disneyland',
    visitDateIso: '2026-10-05T00:00:00.000',
    entryTimeHour: 9,
    entryTimeMinute: 0,
    exitTimeHour: 21,
    exitTimeMinute: 0,
    wantsBreakfast: false,
    wantsLunch: false,
    wantsDinner: false,
    usesVacationPackage: true,
    hasUnlimitedAttractionRides: true,
  );
}

void main() {
  test('実測待ち時間が無い最高優先度グリーティングは40分の計画値を使う', () {
    final greeting = _facility(
      'greeting',
      category: FacilityCategory.greeting,
      priority: PriorityLevel.highest,
    );
    final filler = _facility(
      'filler',
      category: FacilityCategory.attraction,
    );

    final schedule = const ScheduleEngine().generate(
      settings: _settings(),
      facilities: [greeting, filler],
      preferences: [
        PlanPreference.initial(facilityId: greeting.id),
        PlanPreference.initial(facilityId: filler.id),
      ],
      morningScores: const {
        'greeting': 100,
        'filler': 0,
      },
      unlimitedRideBufferMinutes: const {
        'filler': 15,
      },
    );

    final greetingItem = schedule.items.firstWhere(
      (item) => item.facilityId == greeting.id,
    );
    final start = greetingItem.startHour * 60 + greetingItem.startMinute;
    final end = greetingItem.endHour * 60 + greetingItem.endMinute;

    expect(
      schedule.items
          .where((item) => item.facilityId != null)
          .first
          .facilityId,
      greeting.id,
    );
    expect(greetingItem.estimatedWaitMinutes, 40);
    expect(greetingItem.experienceMinutes, 10);
    expect(end - start, 50);
    expect(greetingItem.waitEstimateSource, contains('実測値ではありません'));
    expect(greetingItem.reason, contains('計画用暫定値'));
    expect(greetingItem.reason, isNot(contains('通常待機難易度は最大約40分')));
  });

  test('高優先度グリーティングの計画用待ち時間は30分', () {
    final greeting = _facility(
      'greeting_high',
      category: FacilityCategory.greeting,
      priority: PriorityLevel.high,
    );
    final filler = _facility(
      'filler',
      category: FacilityCategory.attraction,
    );

    final schedule = const ScheduleEngine().generate(
      settings: _settings(),
      facilities: [greeting, filler],
      preferences: [
        PlanPreference.initial(facilityId: greeting.id),
        PlanPreference.initial(facilityId: filler.id),
      ],
      unlimitedRideBufferMinutes: const {
        'filler': 15,
      },
    );

    final greetingItem = schedule.items.firstWhere(
      (item) => item.facilityId == greeting.id,
    );
    expect(greetingItem.estimatedWaitMinutes, 30);
  });

  test('キャラクター誕生日は240分を確保し480分級リスクを理由へ表示する', () {
    final greeting = _facility(
      'birthday_greeting',
      category: FacilityCategory.greeting,
      priority: PriorityLevel.highest,
    );
    final unlimitedRide = _facility(
      'unlimited_ride',
      category: FacilityCategory.attraction,
      priority: PriorityLevel.highest,
    );
    const birthdayPlan = GreetingWaitPlanningValue(
      facilityId: 'birthday_greeting',
      waitMinutes: 240,
      baseWaitMinutes: 40,
      parkCrowdMultiplier: 1.0,
      isCharacterBirthday: true,
      birthdayCharacterNames: ['ミッキーマウス'],
      birthdayPlanningWaitMinutes: 240,
      birthdayExtremeRiskMinutes: 480,
      birthdayOpeningUrgencyBonus: 180,
      source: '誕生日テスト計画値（実測値ではありません）',
    );

    final schedule = const ScheduleEngine().generate(
      settings: _settings(),
      facilities: [unlimitedRide, greeting],
      preferences: [
        PlanPreference.initial(facilityId: unlimitedRide.id),
        PlanPreference.initial(facilityId: greeting.id),
      ],
      unlimitedRideBufferMinutes: const {
        'unlimited_ride': 15,
      },
      greetingWaitPlanning: const {
        'birthday_greeting': birthdayPlan,
      },
    );

    final planned = schedule.items.where((item) => item.facilityId != null).toList();
    final greetingItem = planned.firstWhere(
      (item) => item.facilityId == greeting.id,
    );

    expect(planned.first.facilityId, greeting.id);
    expect(greetingItem.estimatedWaitMinutes, 240);
    expect(greetingItem.reason, contains('特殊混雑日'));
    expect(greetingItem.reason, contains('480分級'));
  });

}
