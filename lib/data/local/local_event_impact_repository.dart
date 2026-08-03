import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/event_impact.dart';
import '../../domain/repositories/event_impact_repository.dart';

class LocalEventImpactRepository implements EventImpactRepository {
  const LocalEventImpactRepository([this._assetBundle]);

  final AssetBundle? _assetBundle;

  AssetBundle get _bundle => _assetBundle ?? rootBundle;

  @override
  Future<List<EventImpact>> loadEventImpacts({required String parkId}) async {
    final assetPath = switch (parkId) {
      'tokyo_disneyland' => 'assets/master/events/tdl_event_impacts.json',
      'tokyo_disneysea' => 'assets/master/events/tds_event_impacts.json',
      _ => null,
    };

    if (assetPath == null) {
      return const [];
    }

    final source = await _bundle.loadString(assetPath);
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('イベント影響マスターのルート要素が不正です。');
    }

    final rawItems = decoded['impacts'];
    if (rawItems is! List) {
      return const [];
    }

    return List<EventImpact>.unmodifiable(
      rawItems
          .whereType<Map<String, dynamic>>()
          .map(EventImpact.fromJson)
          .where((impact) => impact.parkId == parkId && impact.enabled),
    );
  }
}
