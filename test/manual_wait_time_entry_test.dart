import 'package:disney_planner/domain/entities/manual_wait_time_entry.dart';
import 'package:disney_planner/domain/enums/live_operation_availability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('differenceMinutes reports increase from previous value', () {
    final entry = ManualWaitTimeEntry(
      parkId: 'tokyo_disneysea',
      facilityId: 'facility',
      availability: LiveOperationAvailability.operating,
      updatedAt: DateTime.now(),
      standbyMinutes: 60,
      previousStandbyMinutes: 45,
    );

    expect(entry.differenceMinutes, 15);
    expect(entry.isStale, isFalse);
  });

  test('entry older than 30 minutes is stale', () {
    final entry = ManualWaitTimeEntry(
      parkId: 'tokyo_disneyland',
      facilityId: 'facility',
      availability: LiveOperationAvailability.operating,
      updatedAt: DateTime.now().subtract(const Duration(minutes: 31)),
      standbyMinutes: 30,
    );

    expect(entry.isStale, isTrue);
  });
}
