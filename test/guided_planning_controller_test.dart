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

    controller.answer('AI質問を始める');
    controller.answer('フード・ドリンク');
    controller.answer('季節限定メニュー');
    controller.answer('両方入れたい');
    controller.answer('季節限定を優先');
    controller.answer('時間が合えば');
    controller.answer('フードだけ');

    expect(controller.step, GuidedPlanningStep.completed);
    expect(controller.primaryFocus, GuidedPlanningFocus.food);
    expect(controller.wantsSeasonalMenus, isTrue);
    expect(controller.wantsSeasonalEntertainment, isFalse);
    expect(controller.summaryItems, isNotEmpty);
  });
}
