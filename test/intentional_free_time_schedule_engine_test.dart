import 'package:disney_planner/domain/entities/free_time_preference.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/preferred_time.dart';
import 'package:disney_planner/domain/services/schedule_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled intentional free time keeps legacy flexible block behavior', () {
    final schedule = const ScheduleEngine().generate(
      settings: TripSettings.initial().copyWith(
        entryTimeHour: 9,
        entryTimeMinute: 0,
        exitTimeHour: 21,
        exitTimeMinute: 0,
        wantsLunch: false,
        wantsDinner: false,
      ),
      facilities: const [],
      preferences: const [],
    );

    expect(
      schedule.items.where((item) => item.id.startsWith('intentional_free_time_')),
      isEmpty,
    );
  });

  test('enabled preference promotes a qualifying flexible block to intentional free time', () {
    final schedule = const ScheduleEngine().generate(
      settings: TripSettings.initial().copyWith(
        entryTimeHour: 9,
        entryTimeMinute: 0,
        exitTimeHour: 21,
        exitTimeMinute: 0,
        wantsLunch: false,
        wantsDinner: false,
        freeTimePreference: const FreeTimePreference(
          enabled: true,
          targetMinutes: 90,
          minimumBlockMinutes: 60,
          preferredTime: PreferredTime.anytime,
        ),
      ),
      facilities: const [],
      preferences: const [],
    );

    final block = schedule.items.singleWhere(
      (item) => item.id.startsWith('intentional_free_time_'),
    );
    final duration = (block.endHour * 60 + block.endMinute) -
        (block.startHour * 60 + block.startMinute);
    expect(block.title, '予定を入れない自由時間');
    expect(duration, greaterThanOrEqualTo(90));
    expect(block.reason, contains('意図的な自由時間'));
  });
}
