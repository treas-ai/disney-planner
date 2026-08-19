import 'package:flutter_test/flutter_test.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';

void main() {
  test('Priority Pass is disabled while DPA remains available', () {
    final settings = TripSettings.initial();
    expect(settings.canUsePriorityPass, isFalse);
    expect(settings.canUseDpa, isTrue);
  });

  test('legacy persisted Priority Pass flag is retired on restore', () {
    final json = TripSettings.initial().toJson();
    json['canUsePriorityPass'] = true;
    final restored = TripSettings.fromJson(json);
    expect(restored.canUsePriorityPass, isFalse);
    expect(restored.canUseDpa, isTrue);
  });
}
