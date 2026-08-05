import 'dart:convert';

import 'package:disney_planner/domain/entities/wish_event_pack.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('current summer pack contains expanded TDL and TDS data', () async {
    final raw = await rootBundle.loadString(
      'assets/master/events/wish_packs/summer_2026.json',
    );
    final pack = WishEventPack.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );

    expect(pack.items.any((item) => item.name.contains('ピクシーダストソーダ')), isTrue);
    expect(pack.items.any((item) => item.name == '冷製シーフードパスタ'), isTrue);
    expect(pack.items.any((item) => item.name.contains('シェイブアイス')), isTrue);
  });
}
