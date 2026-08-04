import 'dart:convert';

import 'package:disney_planner/domain/entities/wish_event_pack.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('summer 2026 pack contains eligible special drinks', () async {
    final raw = await rootBundle.loadString(
      'assets/master/events/wish_packs/summer_2026.json',
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final pack = WishEventPack.fromJson(decoded);

    expect(pack.id, 'summer_2026');
    expect(pack.items, isNotEmpty);
    expect(
      pack.items.any(
        (item) =>
            item.name.contains('シトラス＆マスカット') &&
            item.freeDrinkEligible,
      ),
      isTrue,
    );
    expect(
      pack.items.any(
        (item) =>
            item.name == '冷製ガンボスープ' &&
            item.freeDrinkEligible,
      ),
      isTrue,
    );
    expect(
      pack.items.any(
        (item) =>
            item.name == 'グアバドリンク' &&
            item.freeDrinkEligible,
      ),
      isTrue,
    );
  });
}
