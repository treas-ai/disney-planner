import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('旧canUseDpa保存データは最大1個へ移行する', () {
    final settings = TripSettings.fromJson({
      ...TripSettings.initial().toJson(),
      'canUseDpa': true,
    }..remove('attractionDpaMaxUses'));

    expect(settings.attractionDpaMaxUses, 1);
    expect(settings.canUseDpa, isTrue);
  });

  test('DPA上限0はcanUseDpaもfalseへ同期する', () {
    final settings = TripSettings.initial().copyWith(attractionDpaMaxUses: 0);
    expect(settings.attractionDpaMaxUses, 0);
    expect(settings.canUseDpa, isFalse);
  });

  test('DPA上限2は保存復元できる', () {
    final original = TripSettings.initial().copyWith(attractionDpaMaxUses: 2);
    final restored = TripSettings.fromJson(original.toJson());
    expect(restored.attractionDpaMaxUses, 2);
    expect(restored.canUseDpa, isTrue);
  });
}
