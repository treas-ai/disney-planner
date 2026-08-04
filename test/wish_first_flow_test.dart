import 'package:disney_planner/app/state/app_state.dart';
import 'package:disney_planner/data/local/app_state_storage.dart';
import 'package:disney_planner/domain/repositories/facility_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmptyFacilityRepository implements FacilityRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wish selection is available before facilities are selected', () {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      storage: AppStateStorage(),
      facilityRepository: _EmptyFacilityRepository(),
    );

    state.toggleWishSelected('wish-drink', true);

    expect(state.selectedWishCount, 1);
    expect(state.selectedFacilities, isEmpty);
  });
}
