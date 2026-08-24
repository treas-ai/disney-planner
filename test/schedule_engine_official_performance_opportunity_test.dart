import 'package:disney_planner/domain/entities/official_performance_opportunity.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/schedule_item_type.dart';
import 'package:disney_planner/domain/services/schedule_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('long evening gap shows exact official performance opportunities', () {
    final settings = TripSettings.initial().copyWith(
      parkId: 'tokyo_disneyland',
      visitDateIso: '2026-08-29T00:00:00.000',
      entryTimeHour: 9,
      entryTimeMinute: 0,
      exitTimeHour: 21,
      exitTimeMinute: 0,
      wantsBreakfast: false,
      wantsLunch: false,
      wantsDinner: false,
    );

    final schedule = const ScheduleEngine().generate(
      settings: settings,
      facilities: const [],
      preferences: const [],
      officialPerformanceOpportunities: const [
        OfficialPerformanceOpportunity(
          facilityId: 'harmony',
          name: 'ディズニー・ハーモニー・イン・カラー',
          startMinutes: 17 * 60,
          endMinutes: 17 * 60 + 20,
          supportsDpa: true,
        ),
        OfficialPerformanceOpportunity(
          facilityId: 'electrical',
          name: '東京ディズニーランド・エレクトリカルパレード・ドリームライツ',
          startMinutes: 19 * 60 + 45,
          endMinutes: 20 * 60 + 30,
          supportsDpa: true,
        ),
        OfficialPerformanceOpportunity(
          facilityId: 'reach',
          name: 'Reach for the Stars: Everlasting Dreams',
          startMinutes: 20 * 60 + 55,
          endMinutes: 21 * 60 + 20,
          supportsDpa: true,
        ),
      ],
    );

    final blocks = schedule.items
        .where((item) => item.type == ScheduleItemType.breakTime)
        .toList(growable: false);

    expect(blocks, isNotEmpty);
    final combined = blocks.map((item) => '${item.reason} ${item.note}').join(' ');
    expect(combined, contains('17:00 ディズニー・ハーモニー・イン・カラー'));
    expect(combined, contains('19:45 東京ディズニーランド・エレクトリカルパレード'));
    expect(combined, contains('20:55 Reach for the Stars'));
    expect(combined, contains('公式の日付別公演データ'));
  });
}
