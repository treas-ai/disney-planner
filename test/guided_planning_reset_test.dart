import 'package:disney_planner/app/state/app_state.dart';
import 'package:disney_planner/data/local/app_state_storage.dart';
import 'package:disney_planner/domain/entities/wish_item.dart';
import 'package:disney_planner/domain/enums/wish_item_category.dart';
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

  AppState createState() {
    SharedPreferences.setMockInitialValues({});
    return AppState(
      storage: AppStateStorage(),
      facilityRepository: _EmptyFacilityRepository(),
    );
  }

  test('restart can clear previous wish selection and guided answers', () {
    final state = createState();
    final controller = GuidedPlanningController(appState: state);

    state.toggleWishSelected('old-wish', true);
    controller.answer('始める');
    controller.answer('バランスよく');
    controller.answer('季節限定メニュー');

    expect(state.selectedWishCount, 1);
    expect(controller.wantsSeasonalMenus, isTrue);

    controller.restart(clearWishSelection: true);

    expect(state.selectedWishCount, 0);
    expect(controller.step, GuidedPlanningStep.welcome);
    expect(controller.wantsSeasonalMenus, isFalse);
  });

  test('guided result can replace an old selection', () {
    final state = createState();
    final controller = GuidedPlanningController(appState: state);
    final items = [
      WishItem(
        id: 'new-attraction',
        parkId: state.tripSettings.parkId,
        eventPackId: 'facility_master',
        name: '新しい候補',
        category: WishItemCategory.attraction,
        venueFacilityIds: ['new-attraction'],
        venueNames: ['新しい候補'],
        startDate: DateTime(2026),
        endDate: DateTime(2030),
      ),
    ];

    state.toggleWishSelected('old-wish', true);
    controller.answer('始める');
    controller.answer('アトラクションを重視');
    controller.confirmCurrentMultiSelection();
    controller.confirmCurrentMultiSelection();
    controller.answer('アトラクションも含める');

    controller.applyToWishList(items);

    expect(state.wishStateFor('old-wish').selected, isFalse);
    expect(state.wishStateFor('new-attraction').selected, isTrue);
    expect(state.selectedWishCount, 1);
  });
}
