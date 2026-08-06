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

  test('seasonal preference can be selected and changed', () {
    SharedPreferences.setMockInitialValues({});

    final state = AppState(
      storage: AppStateStorage(),
      facilityRepository: _EmptyFacilityRepository(),
    );
    final controller = GuidedPlanningController(appState: state);

    controller.answer('AI質問を始める');
    controller.answer('バランスよく');
    controller.answer('完全にバランス');
    controller.answer('両方バランスよく');
    controller.answer('AIにおまかせ');
    controller.answer('時間が合えば');

    expect(controller.step, GuidedPlanningStep.seasonalPreference);

    controller.answer('フードだけ');

    expect(controller.step, GuidedPlanningStep.completed);
    expect(controller.wantsSeasonalMenus, isTrue);
    expect(controller.wantsSeasonalEntertainment, isFalse);

    controller.goBack();

    expect(controller.step, GuidedPlanningStep.seasonalPreference);

    controller.answer('今回は重視しない');

    expect(controller.step, GuidedPlanningStep.completed);
    expect(controller.wantsSeasonalMenus, isFalse);
    expect(controller.wantsSeasonalEntertainment, isFalse);
  });
}
