import 'package:disney_planner/domain/entities/free_time_preference.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/preferred_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('intentional free-time preference defaults are backward compatible', () {
    final restored = TripSettings.fromJson(TripSettings.initial().toJson()
      ..remove('freeTimePreference'));
    expect(restored.freeTimePreference.enabled, isFalse);
    expect(restored.freeTimePreference.targetMinutes, 0);
    expect(restored.freeTimePreference.minimumBlockMinutes, 60);
    expect(restored.freeTimePreference.preferredTime, PreferredTime.anytime);
  });

  test('intentional free-time preference round-trips through TripSettings', () {
    final settings = TripSettings.initial().copyWith(
      freeTimePreference: const FreeTimePreference(
        enabled: true,
        targetMinutes: 90,
        minimumBlockMinutes: 60,
        preferredTime: PreferredTime.afternoon,
      ),
    );
    final restored = TripSettings.fromJson(settings.toJson());
    expect(restored.freeTimePreference.enabled, isTrue);
    expect(restored.freeTimePreference.targetMinutes, 90);
    expect(restored.freeTimePreference.minimumBlockMinutes, 60);
    expect(restored.freeTimePreference.preferredTime, PreferredTime.afternoon);
  });
}
