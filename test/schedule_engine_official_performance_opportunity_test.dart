import 'package:disney_planner/domain/entities/official_performance_opportunity.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/schedule_item_type.dart';
import 'package:disney_planner/domain/services/schedule_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public evening performances become actual schedule items', () {
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
          facilityId: 'electrical',
          name: '東京ディズニーランド・エレクトリカルパレード・ドリームライツ',
          startMinutes: 19 * 60 + 45,
          endMinutes: 20 * 60 + 30,
          supportsDpa: true,
        ),
      ],
    );

    final performance = schedule.items.singleWhere(
      (item) => item.facilityId == 'electrical',
    );
    expect(performance.type, ScheduleItemType.facility);
    expect(performance.startHour, 19);
    expect(performance.startMinute, 25);
    expect(performance.endHour, 20);
    expect(performance.endMinute, 30);
    expect(performance.reason, contains('公演開始19:45'));
  });

  test('unselected Entry Request show is not treated as won', () {
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
          facilityId: 'magical_music',
          name: 'ミッキーのマジカルミュージックワールド',
          startMinutes: 17 * 60 + 10,
          endMinutes: 17 * 60 + 35,
          requiresEntryRequest: true,
          supportsDpa: true,
        ),
      ],
    );

    expect(
      schedule.items.where((item) => item.facilityId == 'magical_music'),
      isEmpty,
    );
    final combined = schedule.items
        .where((item) => item.type == ScheduleItemType.breakTime)
        .map((item) => '${item.title} ${item.reason} ${item.note}')
        .join(' ');
    expect(combined, isNot(contains('エントリー受付結果待ち')));
    expect(combined, contains('未当選のため時間は予約していません'));
    expect(combined, contains('17:10 ミッキーのマジカルミュージックワールド'));
  });

  test('valuable performance may softly extend desired exit time', () {
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
          facilityId: 'late_show',
          name: 'Late Evening Performance',
          startMinutes: 20 * 60 + 55,
          endMinutes: 21 * 60 + 20,
          supportsDpa: true,
        ),
      ],
    );

    final performance = schedule.items.singleWhere(
      (item) => item.facilityId == 'late_show',
    );
    expect(performance.endHour, 21);
    expect(performance.endMinute, 20);
    expect(performance.reason, contains('希望退園21:00を20分超えます'));
    expect(performance.reason, contains('予定価値'));
    expect(performance.reason, contains('超過コスト'));

    final exit = schedule.items.singleWhere(
      (item) => item.type == ScheduleItemType.exit,
    );
    expect(exit.startHour, 21);
    expect(exit.startMinute, 20);
    expect(exit.note, '希望退園時刻は21:00です。');
  });

  test('overtime is rejected when its cost exceeds candidate value', () {
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
          facilityId: 'too_late_show',
          name: 'Too Late Performance',
          startMinutes: 20 * 60 + 55,
          endMinutes: 22 * 60,
        ),
      ],
    );

    expect(
      schedule.items.where((item) => item.facilityId == 'too_late_show'),
      isEmpty,
    );
    final exit = schedule.items.singleWhere(
      (item) => item.type == ScheduleItemType.exit,
    );
    expect(exit.startHour, 21);
    expect(exit.startMinute, 0);
    expect(exit.reason, '設定された退園時間です。');
  });

  test('unselected morning public performance is not pre-reserved', () {
    final settings = TripSettings.initial().copyWith(
      parkId: 'tokyo_disneyland',
      visitDateIso: '2026-08-29T00:00:00.000',
      entryTimeHour: 9,
      entryTimeMinute: 10,
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
          facilityId: 'baymax_cooldown',
          name: 'ベイマックスのミッション・クールダウン',
          startMinutes: 10 * 60,
          endMinutes: 10 * 60 + 15,
        ),
      ],
    );

    // An unselected morning public performance must not consume the
    // rope-drop window. Morning time remains available for attractions.
    expect(
      schedule.items.where((item) => item.facilityId == 'baymax_cooldown'),
      isEmpty,
    );
  });

}
