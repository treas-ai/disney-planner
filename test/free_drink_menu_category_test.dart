import 'package:disney_planner/domain/enums/wish_item_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('free drink menu categories include drinks juice soup and jelly', () {
    expect(WishItemCategory.specialDrink.isFreeDrinkMenuCategory, isTrue);
    expect(WishItemCategory.cafeDrink.isFreeDrinkMenuCategory, isTrue);
    expect(WishItemCategory.juice.isFreeDrinkMenuCategory, isTrue);
    expect(WishItemCategory.soup.isFreeDrinkMenuCategory, isTrue);
    expect(WishItemCategory.drinkJelly.isFreeDrinkMenuCategory, isTrue);
    expect(WishItemCategory.food.isFreeDrinkMenuCategory, isFalse);
  });
}
