import 'package:disney_planner/domain/enums/wish_item_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('greeting category has Japanese label', () {
    expect(WishItemCategory.greeting.label, 'キャラクターグリーティング');
  });
}
