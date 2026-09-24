import 'package:disney_planner/domain/entities/wish_item_state.dart';
import 'package:disney_planner/domain/enums/wish_importance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:disney_planner/domain/enums/preferred_time.dart';
import 'package:disney_planner/domain/enums/wait_tolerance.dart';

void main() {
  test('wish state serializes selection completion and priority', () {
    const state = WishItemState(
      itemId: 'drink',
      selected: true,
      completed: true,
      priority: 5,
    );

    final restored = WishItemState.fromJson(state.toJson());

    expect(restored.itemId, 'drink');
    expect(restored.selected, isTrue);
    expect(restored.completed, isTrue);
    expect(restored.priority, 5);
  });
  test('wish importance maps legacy priority to beginner-facing meaning', () {
    expect(const WishItemState(itemId: 'a', priority: 2).importance, WishImportance.optional);
    expect(const WishItemState(itemId: 'b', priority: 3).importance, WishImportance.normal);
    expect(const WishItemState(itemId: 'c', priority: 4).importance, WishImportance.normal);
    expect(const WishItemState(itemId: 'd', priority: 5).importance, WishImportance.mustDo);
  });
  test('advanced wish conditions round-trip without changing beginner defaults', () {
    const base = WishItemState(itemId: 'x');
    expect(base.preferredTime, PreferredTime.anytime);
    expect(base.waitTolerance, WaitTolerance.any);
    final restored = WishItemState.fromJson(base.copyWith(selected: true, preferredTime: PreferredTime.morning, waitTolerance: WaitTolerance.long).toJson());
    expect(restored.preferredTime, PreferredTime.morning);
    expect(restored.waitTolerance, WaitTolerance.long);
    expect(restored.selected, isTrue);
  });
  test('90 minute conditional wait preference round-trips', () {
    const state = WishItemState(
      itemId: 'conditional',
      selected: true,
      priority: 2,
      waitTolerance: WaitTolerance.veryLong,
    );
    final restored = WishItemState.fromJson(state.toJson());
    expect(restored.importance, WishImportance.optional);
    expect(restored.waitTolerance, WaitTolerance.veryLong);
    expect(restored.waitTolerance.maxMinutes, 90);
  });
  test('new wish state defaults to optional while legacy JSON stays normal', () {
    expect(const WishItemState(itemId: 'new').importance, WishImportance.optional);

    final legacy = WishItemState.fromJson(<String, dynamic>{'itemId': 'legacy'});
    expect(legacy.importance, WishImportance.normal);
  });

}
