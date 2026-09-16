import 'package:disney_planner/app/state/app_state.dart';
import 'package:disney_planner/data/local/app_state_storage.dart';
import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/today_access_result.dart';
import 'package:disney_planner/domain/enums/facility_access_method.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/fixed_time_status.dart';
import 'package:disney_planner/domain/enums/today_access_kind.dart';
import 'package:disney_planner/domain/enums/today_access_status.dart';
import 'package:disney_planner/domain/repositories/facility_repository.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmptyFacilityRepository implements FacilityRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Facility _facility({
  required String id,
  required FacilityCategory category,
  bool supportsDpa = false,
  bool supportsMobileOrder = false,
  bool requiresEntryRequest = false,
}) {
  return Facility(
    id: id,
    parkId: 'tokyo_disneyland',
    areaId: 'test',
    name: id,
    category: category,
    coordinate: const Coordinate(latitude: 0, longitude: 0),
    supportsDpa: supportsDpa,
    supportsMobileOrder: supportsMobileOrder,
    requiresEntryRequest: requiresEntryRequest,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('today access result survives json round trip', () {
    final original = TodayAccessResult(
      facilityId: 'ride-a',
      kind: TodayAccessKind.attractionDpa,
      status: TodayAccessStatus.acquired,
      time: '13:20',
      note: 'planned time differed',
      updatedAt: DateTime(2026, 10, 5, 9, 15),
    );

    final restored = TodayAccessResult.fromJson(original.toJson());

    expect(restored.facilityId, 'ride-a');
    expect(restored.kind, TodayAccessKind.attractionDpa);
    expect(restored.status, TodayAccessStatus.acquired);
    expect(restored.time, '13:20');
    expect(restored.fixesTime, isTrue);
  });

  test('acquired DPA overlays today effective preference without changing plan', () {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      storage: AppStateStorage(),
      facilityRepository: _EmptyFacilityRepository(),
    );
    state.addFacility(
      _facility(
        id: 'ride-a',
        category: FacilityCategory.attraction,
        supportsDpa: true,
      ),
    );

    final plannedBefore = state.getPreference('ride-a')!;
    expect(plannedBefore.fixedTimeStatus, FixedTimeStatus.none);

    state.upsertTodayAccessResult(
      TodayAccessResult(
        facilityId: 'ride-a',
        kind: TodayAccessKind.attractionDpa,
        status: TodayAccessStatus.acquired,
        time: '13:20',
        updatedAt: DateTime(2026, 10, 5, 9, 15),
      ),
    );

    final effective = state.effectivePlanPreferencesForToday.single;
    expect(effective.accessMethod, FacilityAccessMethod.dpa);
    expect(effective.scheduledAccessTime, '13:20');
    expect(effective.fixedTimeStatus, FixedTimeStatus.confirmed);

    final plannedAfter = state.getPreference('ride-a')!;
    expect(plannedAfter.fixedTimeStatus, FixedTimeStatus.none);
    expect(plannedAfter.scheduledAccessTime, isEmpty);
  });

  test('mobile order result fixes restaurant time only in today effective plan', () {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      storage: AppStateStorage(),
      facilityRepository: _EmptyFacilityRepository(),
    );
    state.addFacility(
      _facility(
        id: 'restaurant-a',
        category: FacilityCategory.restaurant,
        supportsMobileOrder: true,
      ),
    );

    state.upsertTodayAccessResult(
      TodayAccessResult(
        facilityId: 'restaurant-a',
        kind: TodayAccessKind.mobileOrder,
        status: TodayAccessStatus.acquired,
        time: '13:10',
        updatedAt: DateTime(2026, 10, 5, 10),
      ),
    );

    final effective = state.effectivePlanPreferencesForToday.single;
    expect(effective.reservationTime, '13:10');
    expect(effective.fixedTimeStatus, FixedTimeStatus.confirmed);
    expect(state.getPreference('restaurant-a')!.reservationTime, isEmpty);
  });
}
