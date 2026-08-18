import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/wish_item_state.dart';
import 'package:disney_planner/domain/enums/priority_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explicit skip preference survives JSON round trip', () {
    final preference = PlanPreference.initial(facilityId: 'beauty_and_beast')
        .copyWith(priority: PriorityLevel.highest, isExcluded: true);

    final restored = PlanPreference.fromJson(preference.toJson());

    expect(restored.isExcluded, isTrue);
    expect(restored.priority, PriorityLevel.highest);
  });

  test('legacy preference defaults to not excluded', () {
    final json = PlanPreference.initial(facilityId: 'jungle_cruise').toJson()
      ..remove('isExcluded');

    expect(PlanPreference.fromJson(json).isExcluded, isFalse);
  });

  test('product wish can remain incomplete after first visit', () {
    const state = WishItemState(
      itemId: 'cafe_orleans_special_drinks',
      selected: true,
      priority: 5,
      targetCount: 3,
      completedCount: 1,
      visitCount: 1,
      repeatAllowed: true,
    );

    expect(state.remainingCount, 2);
    expect(state.isFulfilled, isFalse);
    expect(state.repeatAllowed, isTrue);

    final restored = WishItemState.fromJson(state.toJson());
    expect(restored.remainingCount, 2);
    expect(restored.visitCount, 1);
  });

  test('legacy completed wish restores as fulfilled', () {
    final restored = WishItemState.fromJson(const {
      'itemId': 'legacy_drink',
      'selected': true,
      'completed': true,
      'priority': 5,
    });

    expect(restored.isFulfilled, isTrue);
    expect(restored.remainingCount, 0);
  });
}
