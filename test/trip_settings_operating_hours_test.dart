import 'package:flutter_test/flutter_test.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';

void main() {
  test('公式閉園時刻は保存復元できる', () {
    final original = TripSettings.initial().copyWith(
      officialClosingTimeHour: 22,
      officialClosingTimeMinute: 30,
    );

    final restored = TripSettings.fromJson(original.toJson());

    expect(restored.officialClosingTimeHour, 22);
    expect(restored.officialClosingTimeMinute, 30);
    expect(restored.officialClosingTimeLabel, '22:30');
  });

  test('旧保存データでは公式閉園時刻を21時として移行する', () {
    final json = TripSettings.initial().toJson()
      ..remove('officialClosingTimeHour')
      ..remove('officialClosingTimeMinute');

    final restored = TripSettings.fromJson(json);

    expect(restored.officialClosingTimeHour, 21);
    expect(restored.officialClosingTimeMinute, 0);
  });
}
