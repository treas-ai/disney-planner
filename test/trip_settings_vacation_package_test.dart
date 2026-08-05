import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vacation package settings survive JSON round trip', () {
    final settings = TripSettings.initial().copyWith(
      usesVacationPackage: true,
      usesFreeDrinkBenefit: true,
      hasAttractionVoucher: true,
      hasShowVoucher: true,
      hasRestaurantReservation: true,
    );
    final restored = TripSettings.fromJson(settings.toJson());
    expect(restored.usesVacationPackage, isTrue);
    expect(restored.usesFreeDrinkBenefit, isTrue);
    expect(restored.hasAttractionVoucher, isTrue);
    expect(restored.hasShowVoucher, isTrue);
    expect(restored.hasRestaurantReservation, isTrue);
  });
}
