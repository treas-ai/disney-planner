import 'package:disney_planner/domain/entities/wish_item.dart';
import 'package:disney_planner/domain/enums/wish_item_category.dart';
import 'package:disney_planner/domain/services/wish_display_deduplicator.dart';
import 'package:flutter_test/flutter_test.dart';

WishItem makeItem({
  required String id,
  required String name,
  required String pack,
  required String venue,
  String park = 'tokyo_disneyland',
}) => WishItem(
  id: id,
  name: name,
  category: WishItemCategory.entertainment,
  parkId: park,
  venueFacilityIds: ['$id:venue'],
  venueNames: [venue],
  startDate: DateTime(2026, 9, 16),
  endDate: DateTime(2026, 10, 31),
  eventPackId: pack,
);

void main() {
  test('master and seasonal-pack copies are shown once', () {
    final master = makeItem(id: 'facility:night-high', name: 'ナイトハイ・ハロウィーン', pack: 'facility_master', venue: 'ナイトハイ・ハロウィーン');
    final seasonal = makeItem(id: 'halloween2026_night_high', name: 'ナイトハイ・ハロウィーン', pack: 'halloween_2026', venue: 'パークワイド');
    final result = WishDisplayDeduplicator.deduplicate([master, seasonal]);
    expect(result, hasLength(1));
    expect(result.single.id, seasonal.id);
  });

  test('an already-selected duplicate stays visible', () {
    final master = makeItem(id: 'facility:villains', name: 'ザ・ヴィランズ・ハロウィーン“Into the Frenzy”', pack: 'facility_master', venue: 'ザ・ヴィランズ・ハロウィーン“Into the Frenzy”');
    final seasonal = makeItem(id: 'halloween2026_villains', name: 'ザ・ヴィランズ・ハロウィーン“Into the Frenzy”', pack: 'halloween_2026', venue: 'パレードルート');
    final result = WishDisplayDeduplicator.deduplicate([master, seasonal], selectedIds: {master.id});
    expect(result, hasLength(1));
    expect(result.single.id, master.id);
  });

  test('same event name in different parks stays independent', () {
    final land = makeItem(id: 'land-night-high', name: 'ナイトハイ・ハロウィーン', pack: 'halloween_2026', venue: 'パークワイド');
    final sea = makeItem(id: 'sea-night-high', name: 'ナイトハイ・ハロウィーン', pack: 'halloween_2026', venue: 'パークワイド', park: 'tokyo_disneysea');
    expect(WishDisplayDeduplicator.deduplicate([land, sea]), hasLength(2));
  });
}
