import 'package:disney_planner/domain/entities/wish_item.dart';
import 'package:disney_planner/domain/enums/wish_item_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wish item is displayed only during its sales period', () {
    final item = WishItem(
      id: 'summer',
      name: '夏メニュー',
      category: WishItemCategory.specialDrink,
      parkId: 'tokyo_disneysea',
      venueFacilityIds: const [],
      venueNames: const ['店舗'],
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 9, 14),
      eventPackId: 'summer_2026',
    );

    expect(item.isAvailableOn(DateTime(2026, 8, 5)), isTrue);
    expect(item.isAvailableOn(DateTime(2026, 10, 1)), isFalse);
  });
}
