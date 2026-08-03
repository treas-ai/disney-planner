import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/area_connection.dart';
import '../../domain/entities/facility_location.dart';
import '../../domain/repositories/movement_repository.dart';

class LocalMovementRepository implements MovementRepository {
  const LocalMovementRepository([this._assetBundle]);

  final AssetBundle? _assetBundle;

  AssetBundle get _bundle => _assetBundle ?? rootBundle;

  @override
  Future<List<FacilityLocation>> loadFacilityLocations({
    required String parkId,
  }) async {
    final json = await _loadJson('assets/movement/facility_locations.json');
    final rawItems = json['locations'];

    if (rawItems is! List) {
      return const [];
    }

    return List<FacilityLocation>.unmodifiable(
      rawItems
          .whereType<Map<String, dynamic>>()
          .map(FacilityLocation.fromJson)
          .where((location) => location.parkId == parkId),
    );
  }

  @override
  Future<List<AreaConnection>> loadAreaConnections({
    required String parkId,
  }) async {
    final json = await _loadJson('assets/movement/area_connections.json');
    final rawItems = json['connections'];

    if (rawItems is! List) {
      return const [];
    }

    return List<AreaConnection>.unmodifiable(
      rawItems
          .whereType<Map<String, dynamic>>()
          .map(AreaConnection.fromJson)
          .where((connection) => connection.parkId == parkId),
    );
  }

  Future<Map<String, dynamic>> _loadJson(String assetPath) async {
    final source = await _bundle.loadString(assetPath);
    final decoded = jsonDecode(source);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('移動時間マスターのルート要素が不正です。');
    }

    return decoded;
  }
}
