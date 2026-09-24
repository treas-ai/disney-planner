import 'package:disney_planner/domain/entities/wish_item.dart';
import 'package:disney_planner/domain/entities/wish_item_state.dart';
import 'package:disney_planner/domain/enums/preferred_time.dart';
import 'package:disney_planner/domain/enums/priority_level.dart';
import 'package:disney_planner/domain/enums/wait_tolerance.dart';
import 'package:disney_planner/domain/enums/wish_item_category.dart';
import 'package:disney_planner/domain/services/wish_planning_intent_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

WishItem item(String id, {WishItemCategory category = WishItemCategory.attraction}) => WishItem(
  id: id,
  name: id,
  category: category,
  parkId: 'tokyo_disneyland',
  venueFacilityIds: const ['facility'],
  venueNames: const ['facility'],
  startDate: DateTime(2020),
  endDate: DateTime(2030),
  eventPackId: 'test',
);

void main() {
  test('resolves importance count time and wait without execution method state', () {
    final states = <String, WishItemState>{
      'wish': const WishItemState(
        itemId: 'wish', selected: true, priority: 5, targetCount: 2,
        preferredTime: PreferredTime.morning, waitTolerance: WaitTolerance.medium,
      ),
    };
    final result = const WishPlanningIntentResolver().resolve(
      items: [item('wish')], stateFor: (id) => states[id]!,
    ).single;
    expect(result.targetCount, 2);
    expect(result.planPriority, PriorityLevel.highest);
    expect(result.preferredTime, PreferredTime.morning);
    expect(result.waitTolerance, WaitTolerance.medium);
  });

  test('non-repeatable wish remains one occurrence', () {
    const state = WishItemState(itemId: 'show', selected: true, targetCount: 5);
    final result = const WishPlanningIntentResolver().resolve(
      items: [item('show', category: WishItemCategory.entertainment)],
      stateFor: (_) => state,
    ).single;
    expect(result.targetCount, 1);
  });

  test('higher importance defaults do not erase explicit conditions for same facility', () {
    final states = <String, WishItemState>{
      'optional': const WishItemState(
        itemId: 'optional',
        selected: true,
        priority: 2,
        preferredTime: PreferredTime.evening,
        waitTolerance: WaitTolerance.veryLong,
      ),
      'must': const WishItemState(
        itemId: 'must',
        selected: true,
        priority: 5,
      ),
    };
    final result = const WishPlanningIntentResolver().resolve(
      items: [item('optional'), item('must')],
      stateFor: (id) => states[id]!,
    ).single;

    expect(result.planPriority, PriorityLevel.highest);
    expect(result.preferredTime, PreferredTime.evening);
    expect(result.waitTolerance, WaitTolerance.veryLong);
  });

  test('higher importance explicit conditions win conflicting conditions', () {
    final states = <String, WishItemState>{
      'optional': const WishItemState(
        itemId: 'optional',
        selected: true,
        priority: 2,
        preferredTime: PreferredTime.morning,
        waitTolerance: WaitTolerance.long,
      ),
      'must': const WishItemState(
        itemId: 'must',
        selected: true,
        priority: 5,
        preferredTime: PreferredTime.evening,
        waitTolerance: WaitTolerance.veryLong,
      ),
    };
    final result = const WishPlanningIntentResolver().resolve(
      items: [item('optional'), item('must')],
      stateFor: (id) => states[id]!,
    ).single;

    expect(result.preferredTime, PreferredTime.evening);
    expect(result.waitTolerance, WaitTolerance.veryLong);
  });

}
