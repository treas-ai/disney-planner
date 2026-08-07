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
}
