import 'package:disney_planner/app/state/app_state.dart';
import 'package:disney_planner/domain/entities/day_schedule.dart';
import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/schedule_item.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/schedule_item_type.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:disney_planner/features/plan_review/schedule_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('空き時間の手動再乗車は既存予定を動かさず局所挿入する', () async {
    final appState = AppState();
    appState.tripSettings = appState.tripSettings.copyWith(
      parkId: 'tokyo_disneyland',
      visitDateIso: '2026-10-05T00:00:00.000',
      usesVacationPackage: true,
      hasUnlimitedAttractionRides: true,
    );
    appState.daySchedule = DaySchedule(
      id: 'before',
      parkId: 'tokyo_disneyland',
      createdAt: DateTime(2026, 10, 5),
      items: const [
        ScheduleItem(
          id: 'big_thunder',
          title: 'ビッグサンダー・マウンテン',
          type: ScheduleItemType.facility,
          startHour: 12,
          startMinute: 45,
          endHour: 13,
          endMinute: 4,
          facilityId: 'big_thunder',
        ),
        ScheduleItem(
          id: 'splash_first',
          title: 'スプラッシュ・マウンテン',
          type: ScheduleItemType.facility,
          startHour: 13,
          startMinute: 19,
          endHour: 13,
          endMinute: 49,
          facilityId: 'splash',
        ),
        ScheduleItem(
          id: 'free_gap',
          title: '休憩・自由時間',
          type: ScheduleItemType.breakTime,
          startHour: 13,
          startMinute: 49,
          endHour: 16,
          endMinute: 15,
        ),
        ScheduleItem(
          id: 'parade',
          title: '固定パレード',
          type: ScheduleItemType.facility,
          startHour: 16,
          startMinute: 15,
          endHour: 17,
          endMinute: 0,
          facilityId: 'parade',
        ),
      ],
    );

    const splash = Facility(
      id: 'splash',
      parkId: 'tokyo_disneyland',
      areaId: 'critic_country',
      name: 'スプラッシュ・マウンテン',
      category: FacilityCategory.attraction,
      coordinate: Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 15,
    );
    final controller = ScheduleController(appState);
    final choice = FreeTimeImprovementChoice.repeatAttraction(
      facility: splash,
      plannedStartMinutes: 13 * 60 + 49,
      plannedEndMinutes: 14 * 60 + 19,
      estimatedWaitMinutes: 15,
      waitSource: 'バケパ乗り放題の優先入口利用バッファ',
      movementInMinutes: 0,
      movementOutMinutes: 15,
      fitSlackMinutes: 96,
      score: 100,
      repeatNumber: 2,
    );

    await controller.applyFreeTimeImprovement(choice);

    final after = appState.daySchedule!;
    final bigThunder = after.items.singleWhere((item) => item.id == 'big_thunder');
    final firstSplash = after.items.singleWhere((item) => item.id == 'splash_first');
    final parade = after.items.singleWhere((item) => item.id == 'parade');
    final repeat = after.items.singleWhere(
      (item) => item.id.startsWith('manual_repeat_'),
    );

    expect(bigThunder.startTimeLabel, '12:45');
    expect(firstSplash.startTimeLabel, '13:19');
    expect(parade.startTimeLabel, '16:15');
    expect(repeat.startTimeLabel, '13:49');
    expect(repeat.endTimeLabel, '14:19');
    expect(repeat.waitEstimateSource, startsWith('バケーションパッケージ乗り放題'));

    final gaps = after.items.where((item) => item.type == ScheduleItemType.breakTime);
    expect(
      gaps.any((item) => item.startTimeLabel == '13:49'),
      isFalse,
    );
    expect(
      gaps.any((item) => item.startTimeLabel == '14:19' && item.endTimeLabel == '16:15'),
      isTrue,
    );

    while (appState.isSaving) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    controller.dispose();
    appState.dispose();
  });

  test('局所挿入で生じる20分未満の細切れ自由時間は独立カードにしない', () async {
    final appState = AppState();
    appState.tripSettings = appState.tripSettings.copyWith(
      parkId: 'tokyo_disneyland',
      visitDateIso: '2026-10-05T00:00:00.000',
      usesVacationPackage: true,
      hasUnlimitedAttractionRides: true,
    );
    appState.daySchedule = DaySchedule(
      id: 'before_short_gap',
      parkId: 'tokyo_disneyland',
      createdAt: DateTime(2026, 10, 5),
      items: const [
        ScheduleItem(
          id: 'free_gap',
          title: '休憩・自由時間',
          type: ScheduleItemType.breakTime,
          startHour: 14,
          startMinute: 0,
          endHour: 16,
          endMinute: 0,
        ),
      ],
    );

    const ride = Facility(
      id: 'ride',
      parkId: 'tokyo_disneyland',
      areaId: 'area',
      name: 'テストアトラクション',
      category: FacilityCategory.attraction,
      coordinate: Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 15,
    );
    final controller = ScheduleController(appState);
    final choice = FreeTimeImprovementChoice.repeatAttraction(
      facility: ride,
      plannedStartMinutes: 14 * 60 + 15,
      plannedEndMinutes: 14 * 60 + 45,
      estimatedWaitMinutes: 15,
      waitSource: 'バケパ乗り放題の優先入口利用バッファ',
      movementInMinutes: 15,
      movementOutMinutes: 0,
      fitSlackMinutes: 75,
      score: 100,
      repeatNumber: 2,
    );

    await controller.applyFreeTimeImprovement(choice);

    final after = appState.daySchedule!;
    final gaps = after.items
        .where((item) => item.type == ScheduleItemType.breakTime)
        .toList(growable: false);
    expect(
      gaps.any((item) => item.startTimeLabel == '14:00' && item.endTimeLabel == '14:15'),
      isFalse,
    );
    expect(
      gaps.any((item) => item.startTimeLabel == '14:45' && item.endTimeLabel == '16:00'),
      isTrue,
    );

    while (appState.isSaving) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    controller.dispose();
    appState.dispose();
  });


  test('手動再乗車を個別削除すると前後の自由時間へ戻して結合する', () async {
    final appState = AppState();
    appState.tripSettings = appState.tripSettings.copyWith(
      parkId: 'tokyo_disneyland',
      visitDateIso: '2026-10-05T00:00:00.000',
      usesVacationPackage: true,
      hasUnlimitedAttractionRides: true,
    );
    appState.daySchedule = DaySchedule(
      id: 'repeat_remove',
      parkId: 'tokyo_disneyland',
      createdAt: DateTime(2026, 10, 5),
      items: const [
        ScheduleItem(
          id: 'free_before',
          title: '休憩・自由時間',
          type: ScheduleItemType.breakTime,
          startHour: 13,
          startMinute: 49,
          endHour: 14,
          endMinute: 4,
        ),
        ScheduleItem(
          id: 'manual_repeat_20261005_beauty_1',
          title: '美女と野獣“魔法のものがたり”（2回目）',
          type: ScheduleItemType.facility,
          startHour: 14,
          startMinute: 4,
          endHour: 14,
          endMinute: 32,
          facilityId: 'beauty',
          estimatedWaitMinutes: 20,
          experienceMinutes: 8,
          waitEstimateSource:
              'バケーションパッケージ乗り放題（優先入口利用バッファ20分・Disney Planner計画値）',
        ),
        ScheduleItem(
          id: 'free_after',
          title: '休憩・自由時間',
          type: ScheduleItemType.breakTime,
          startHour: 14,
          startMinute: 32,
          endHour: 16,
          endMinute: 15,
        ),
      ],
    );

    final controller = ScheduleController(appState);
    expect(
      controller.removeManualRepeat('manual_repeat_20261005_beauty_1'),
      isTrue,
    );

    final after = appState.daySchedule!;
    expect(
      after.items.any((item) => item.id.startsWith('manual_repeat_')),
      isFalse,
    );
    final gaps = after.items
        .where((item) => item.type == ScheduleItemType.breakTime)
        .toList(growable: false);
    expect(gaps.length, 1);
    expect(gaps.single.startTimeLabel, '13:49');
    expect(gaps.single.endTimeLabel, '16:15');

    while (appState.isSaving) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    controller.dispose();
    appState.dispose();
  });

}
