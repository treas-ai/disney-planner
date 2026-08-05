import 'package:disney_planner/domain/services/time_rounding_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = TimeRoundingService();

  test('minutes are always rounded up to five-minute units', () {
    expect(service.ceilMinutes(0), 0);
    expect(service.ceilMinutes(1), 5);
    expect(service.ceilMinutes(3), 5);
    expect(service.ceilMinutes(5), 5);
    expect(service.ceilMinutes(6), 10);
    expect(service.ceilMinutes(12), 15);
    expect(service.ceilMinutes(67), 70);
  });
}
