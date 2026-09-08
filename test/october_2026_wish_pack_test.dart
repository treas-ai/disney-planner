import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disney_planner/domain/entities/wish_event_pack.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Halloween pack is active only from 9/16 through 10/31', () async {
    final source = await rootBundle.loadString(
      'assets/master/events/wish_packs/halloween_2026.json',
    );
    final pack = WishEventPack.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
    expect(pack.isAvailableOn(DateTime(2026, 9, 15)), isFalse);
    expect(pack.isAvailableOn(DateTime(2026, 9, 16)), isTrue);
    expect(pack.isAvailableOn(DateTime(2026, 10, 31)), isTrue);
    expect(pack.isAvailableOn(DateTime(2026, 11, 1)), isFalse);
  });

  test('summer pack expires before Halloween pack begins', () async {
    final source = await rootBundle.loadString(
      'assets/master/events/wish_packs/summer_2026.json',
    );
    final pack = WishEventPack.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
    expect(pack.isAvailableOn(DateTime(2026, 9, 14)), isTrue);
    expect(pack.isAvailableOn(DateTime(2026, 9, 16)), isFalse);
  });
}
