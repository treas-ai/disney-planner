import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/live_operating_status.dart';
import '../../domain/entities/live_pass_status.dart';
import '../../domain/entities/live_wait_time.dart';
import '../../domain/repositories/live_data_repository.dart';
import '../../domain/repositories/live_wait_time_repository.dart';
import 'local_live_wait_time_repository.dart';

class LocalLiveDataRepository implements LiveDataRepository {
  const LocalLiveDataRepository([this._manualRepository]);

  final LiveWaitTimeRepository? _manualRepository;

  LiveWaitTimeRepository get _waitTimeRepository {
    return _manualRepository ?? const LocalLiveWaitTimeRepository();
  }

  @override
  Future<List<LiveWaitTime>> fetchWaitTimes({required String parkId}) async {
    final assetItems = await _loadList('assets/live/wait_times.json');
    final assetWaitTimes = assetItems
        .map(LiveWaitTime.fromJson)
        .where((item) => item.isValid && item.parkId == parkId)
        .toList(growable: false);

    final manualWaitTimes = await _waitTimeRepository.loadForPark(parkId);
    final merged = <String, LiveWaitTime>{};

    for (final item in assetWaitTimes) {
      merged[item.facilityId] = item;
    }
    for (final item in manualWaitTimes) {
      merged[item.facilityId] = item;
    }

    final values = merged.values.toList(growable: false)
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return List<LiveWaitTime>.unmodifiable(values);
  }

  @override
  Future<List<LiveOperatingStatus>> fetchOperatingStatuses({
    required String parkId,
  }) async {
    final items = await _loadList('assets/live/operating_status.json');
    return List<LiveOperatingStatus>.unmodifiable(
      items
          .map(LiveOperatingStatus.fromJson)
          .where((item) => item.isValid && item.parkId == parkId),
    );
  }

  @override
  Future<List<LivePassStatus>> fetchPassStatuses({
    required String parkId,
  }) async {
    final items = await _loadList('assets/live/pass_status.json');
    return List<LivePassStatus>.unmodifiable(
      items
          .map(LivePassStatus.fromJson)
          .where((item) => item.isValid && item.parkId == parkId),
    );
  }

  Future<List<Map<String, dynamic>>> _loadList(String assetPath) async {
    try {
      final source = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(source);
      final rawItems = decoded is List
          ? decoded
          : decoded is Map<String, dynamic>
          ? decoded['items']
          : null;

      if (rawItems is! List) {
        return const [];
      }

      return rawItems
          .whereType<Map>()
          .map((item) {
            return item.map((key, value) => MapEntry(key.toString(), value));
          })
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
