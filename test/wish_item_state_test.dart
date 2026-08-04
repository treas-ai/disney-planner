import 'package:disney_planner/domain/entities/wish_item_state.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
