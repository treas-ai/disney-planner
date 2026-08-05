import 'package:disney_planner/app/state/app_state.dart';
import 'package:disney_planner/data/local/app_state_storage.dart';
import 'package:disney_planner/domain/repositories/facility_repository.dart';
import 'package:disney_planner/features/wish_list/guided_planning_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmptyFacilityRepository implements FacilityRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('guided planning reaches completed state', () {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      storage: AppStateStorage(),
      facilityRepository: _EmptyFacilityRepository(),
    );
    final controller = GuidedPlanningController(appState: state);

    controller.answer('始める');
    controller.answer('グルメを重視');
    controller.answer('利用する');
    controller.answer('活用する');
    controller.answer('スペシャルドリンク');
    controller.confirmFoodSelection();
    controller.answer('飲食中心にする');

    expect(controller.step, GuidedPlanningStep.completed);
    expect(controller.usesVacationPackage, isTrue);
    expect(controller.usesFreeDrink, isTrue);
  });
}
