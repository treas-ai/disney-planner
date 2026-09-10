import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vacation package settings survive JSON round trip', () {
    final settings = TripSettings.initial().copyWith(
      usesVacationPackage: true,
      hasUnlimitedAttractionRides: true,
      usesFreeDrinkBenefit: true,
      hasAttractionVoucher: true,
      hasShowVoucher: true,
      hasRestaurantReservation: true,
    );
    final restored = TripSettings.fromJson(settings.toJson());
    expect(restored.usesVacationPackage, isTrue);
    expect(restored.hasUnlimitedAttractionRides, isTrue);
    expect(restored.usesFreeDrinkBenefit, isTrue);
    expect(restored.hasAttractionVoucher, isTrue);
    expect(restored.hasShowVoucher, isTrue);
    expect(restored.hasRestaurantReservation, isTrue);
  });
  test('old vacation package data defaults unlimited rides to false', () {
    final json = TripSettings.initial().copyWith(usesVacationPackage: true).toJson()
      ..remove('hasUnlimitedAttractionRides');
    final restored = TripSettings.fromJson(json);
    expect(restored.hasUnlimitedAttractionRides, isFalse);
  });
}
