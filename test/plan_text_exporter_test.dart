import 'package:disney_planner/domain/entities/day_schedule.dart';
import 'package:disney_planner/domain/entities/schedule_item.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/schedule_item_type.dart';
import 'package:disney_planner/domain/services/plan_text_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const exporter = PlanTextExporter();
  const settings = TripSettings(
    parkId: 'tokyo_disneyland',
    entryTimeHour: 9,
    entryTimeMinute: 0,
    exitTimeHour: 21,
    exitTimeMinute: 0,
    numberOfPeople: 2,
    hasHappyEntry: false,
    canUseDpa: true,
    canUsePriorityPass: true,
    canUseSingleRider: false,
    usesVacationPackage: false,
    usesFreeDrinkBenefit: false,
    hasAttractionVoucher: false,
    hasShowVoucher: false,
    hasRestaurantReservation: false,
    wantsBreakfast: false,
    wantsLunch: true,
    wantsDinner: true,
    isRainy: false,
    hasChildren: false,
  );
  final schedule = DaySchedule(
    id: 'test',
    parkId: 'tokyo_disneyland',
    createdAt: DateTime(2026, 8, 7),
    items: const [
      ScheduleItem(
        id: 'entry',
        title: '入園',
        type: ScheduleItemType.entry,
        startHour: 9,
        startMinute: 0,
        endHour: 9,
        endMinute: 5,
      ),
      ScheduleItem(
        id: 'facility',
        title: 'テストアトラクション',
        type: ScheduleItemType.facility,
        startHour: 9,
        startMinute: 15,
        endHour: 10,
        endMinute: 0,
        reason: '朝は待ち時間が短いため',
      ),
    ],
  );

  test('simple export contains schedule lines', () {
    final text = exporter.export(
      schedule: schedule,
      settings: settings,
      parkName: '東京ディズニーランド',
      preferences: const [],
      validationIssues: const [],
      format: PlanTextExportFormat.simple,
    );

    expect(text, contains('Disney Planner 簡易プラン'));
    expect(text, contains('09:15　テストアトラクション'));
  });

  test('evaluation export contains review sections', () {
    final text = exporter.export(
      schedule: schedule,
      settings: settings,
      parkName: '東京ディズニーランド',
      preferences: const [],
      validationIssues: const [],
      format: PlanTextExportFormat.evaluation,
    );

    expect(text, contains('【利用可能なサービス】'));
    expect(text, contains('AI理由：朝は待ち時間が短いため'));
    expect(text, contains('【改善を評価したい観点】'));
  });
  test('unlimited ride export labels planning buffer separately from standby wait', () {
    final unlimitedSchedule = DaySchedule(
      id: 'unlimited',
      parkId: 'tokyo_disneyland',
      createdAt: DateTime(2026, 10, 5),
      items: const [
        ScheduleItem(
          id: 'unlimited_facility',
          title: '乗り放題対象',
          type: ScheduleItemType.facility,
          startHour: 9,
          startMinute: 15,
          endHour: 9,
          endMinute: 43,
          estimatedWaitMinutes: 20,
          experienceMinutes: 8,
          waitEstimateSource:
              'バケーションパッケージ乗り放題（優先入口利用バッファ20分・Disney Planner計画値）',
        ),
      ],
    );

    final text = exporter.export(
      schedule: unlimitedSchedule,
      settings: settings,
      parkName: '東京ディズニーランド',
      preferences: const [],
      validationIssues: const [],
      format: PlanTextExportFormat.evaluation,
    );

    expect(text, contains('優先入口利用バッファ：20分'));
    expect(text, contains('体験時間：8分'));
    expect(text, contains('合計拘束時間：28分'));
    expect(text, isNot(contains('推定待ち時間：20分')));
  });

}
