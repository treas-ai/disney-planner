import 'package:flutter_test/flutter_test.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/enums/facility_access_method.dart';

void main() {
  test('legacy priority pass preference is migrated to standby', () {
    final preference = PlanPreference.fromJson({
      'id': 'legacy_pp',
      'facilityId': 'facility_1',
      'accessMethod': 'priorityPass',
      'usePriorityPass': true,
      'createdAt': '2026-08-01T00:00:00.000',
    });

    expect(preference.accessMethod, FacilityAccessMethod.standby);
    expect(preference.usePriorityPass, isFalse);
  });
}
