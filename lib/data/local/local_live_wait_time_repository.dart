import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/live_wait_time.dart';
import '../../domain/repositories/live_wait_time_repository.dart';

class LocalLiveWaitTimeRepository implements LiveWaitTimeRepository {
  const LocalLiveWaitTimeRepository();

  static const String _storageKey = 'disney_planner_live_wait_times';

  @override
  Future<List<LiveWaitTime>> loadAll() async {
    final preferences = await SharedPreferences.getInstance();

    final encodedJson = preferences.getString(_storageKey);

    if (encodedJson == null || encodedJson.trim().isEmpty) {
      return const [];
    }

    try {
      final decodedJson = jsonDecode(encodedJson);

      if (decodedJson is! List) {
        return const [];
      }

      final waitTimes = <LiveWaitTime>[];

      for (final item in decodedJson) {
        if (item is! Map) {
          continue;
        }

        final convertedItem = <String, dynamic>{};

        for (final entry in item.entries) {
          convertedItem[entry.key.toString()] = entry.value;
        }

        final waitTime = LiveWaitTime.fromJson(convertedItem);

        if (!waitTime.isValid) {
          continue;
        }

        waitTimes.add(waitTime);
      }

      waitTimes.sort((left, right) {
        return right.updatedAt.compareTo(left.updatedAt);
      });

      return List<LiveWaitTime>.unmodifiable(waitTimes);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<LiveWaitTime>> loadForPark(String parkId) async {
    final normalizedParkId = parkId.trim();

    if (normalizedParkId.isEmpty) {
      return const [];
    }

    final waitTimes = await loadAll();

    return List<LiveWaitTime>.unmodifiable(
      waitTimes
          .where((waitTime) => waitTime.parkId == normalizedParkId)
          .toList(growable: false),
    );
  }

  @override
  Future<LiveWaitTime?> loadForFacility(String facilityId) async {
    final normalizedFacilityId = facilityId.trim();

    if (normalizedFacilityId.isEmpty) {
      return null;
    }

    final waitTimes = await loadAll();

    for (final waitTime in waitTimes) {
      if (waitTime.facilityId == normalizedFacilityId) {
        return waitTime;
      }
    }

    return null;
  }

  @override
  Future<void> save(LiveWaitTime waitTime) async {
    if (!waitTime.isValid) {
      throw ArgumentError('保存する待ち時間情報が不正です。');
    }

    final waitTimes = (await loadAll()).toList(growable: true);

    final existingIndex = waitTimes.indexWhere(
      (existing) => existing.facilityId == waitTime.facilityId,
    );

    if (existingIndex >= 0) {
      waitTimes[existingIndex] = waitTime;
    } else {
      waitTimes.add(waitTime);
    }

    waitTimes.sort((left, right) {
      return right.updatedAt.compareTo(left.updatedAt);
    });

    await _saveAll(waitTimes);
  }

  @override
  Future<void> remove(String facilityId) async {
    final normalizedFacilityId = facilityId.trim();

    if (normalizedFacilityId.isEmpty) {
      return;
    }

    final waitTimes = (await loadAll()).toList(growable: true);

    final originalLength = waitTimes.length;

    waitTimes.removeWhere(
      (waitTime) => waitTime.facilityId == normalizedFacilityId,
    );

    if (originalLength == waitTimes.length) {
      return;
    }

    await _saveAll(waitTimes);
  }

  @override
  Future<void> clearForPark(String parkId) async {
    final normalizedParkId = parkId.trim();

    if (normalizedParkId.isEmpty) {
      return;
    }

    final waitTimes = (await loadAll()).toList(growable: true);

    final originalLength = waitTimes.length;

    waitTimes.removeWhere((waitTime) => waitTime.parkId == normalizedParkId);

    if (originalLength == waitTimes.length) {
      return;
    }

    await _saveAll(waitTimes);
  }

  @override
  Future<void> clearAll() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_storageKey);
  }

  Future<void> _saveAll(List<LiveWaitTime> waitTimes) async {
    final preferences = await SharedPreferences.getInstance();

    final encodedJson = jsonEncode(
      waitTimes.map((waitTime) => waitTime.toJson()).toList(growable: false),
    );

    await preferences.setString(_storageKey, encodedJson);
  }
}
