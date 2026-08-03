import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/activity_history_record.dart';
import '../../domain/enums/activity_history_type.dart';
import '../../domain/repositories/history_repository.dart';

class LocalHistoryRepository implements HistoryRepository {
  const LocalHistoryRepository();

  static const String _storageKey = 'disney_planner_activity_history_v1';
  static const int _maximumRecordCount = 5000;

  @override
  Future<List<ActivityHistoryRecord>> loadAll() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_storageKey);

    if (encoded == null || encoded.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) {
        return const [];
      }

      final records = <ActivityHistoryRecord>[];
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }

        final json = <String, dynamic>{
          for (final entry in item.entries) entry.key.toString(): entry.value,
        };
        final record = ActivityHistoryRecord.fromJson(json);
        if (record.isValid) {
          records.add(record);
        }
      }

      records.sort(
        (left, right) => right.recordedAt.compareTo(left.recordedAt),
      );
      return List<ActivityHistoryRecord>.unmodifiable(records);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<ActivityHistoryRecord>> loadForPark(String parkId) async {
    final normalized = parkId.trim();
    if (normalized.isEmpty) {
      return const [];
    }

    final records = await loadAll();
    return List<ActivityHistoryRecord>.unmodifiable(
      records.where((record) => record.parkId == normalized),
    );
  }

  @override
  Future<List<ActivityHistoryRecord>> loadForFacility(String facilityId) async {
    final normalized = facilityId.trim();
    if (normalized.isEmpty) {
      return const [];
    }

    final records = await loadAll();
    return List<ActivityHistoryRecord>.unmodifiable(
      records.where(
        (record) =>
            record.facilityId == normalized ||
            record.fromFacilityId == normalized ||
            record.toFacilityId == normalized,
      ),
    );
  }

  @override
  Future<List<ActivityHistoryRecord>> loadByType(
    ActivityHistoryType type,
  ) async {
    final records = await loadAll();
    return List<ActivityHistoryRecord>.unmodifiable(
      records.where((record) => record.type == type),
    );
  }

  @override
  Future<void> save(ActivityHistoryRecord record) async {
    if (!record.isValid) {
      throw ArgumentError('保存する行動履歴が不正です。');
    }

    final records = (await loadAll()).toList(growable: true);
    final existingIndex = records.indexWhere((item) => item.id == record.id);

    if (existingIndex >= 0) {
      records[existingIndex] = record;
    } else {
      records.add(record);
    }

    await _persist(records);
  }

  @override
  Future<void> saveAll(Iterable<ActivityHistoryRecord> records) async {
    final validRecords = records.where((record) => record.isValid).toList();
    if (validRecords.isEmpty) {
      return;
    }

    final merged = <String, ActivityHistoryRecord>{
      for (final record in await loadAll()) record.id: record,
      for (final record in validRecords) record.id: record,
    };

    await _persist(merged.values.toList(growable: true));
  }

  @override
  Future<void> remove(String recordId) async {
    final normalized = recordId.trim();
    if (normalized.isEmpty) {
      return;
    }

    final records = (await loadAll()).toList(growable: true)
      ..removeWhere((record) => record.id == normalized);
    await _persist(records);
  }

  @override
  Future<void> clearAll() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }

  Future<void> _persist(List<ActivityHistoryRecord> records) async {
    records.sort((left, right) => right.recordedAt.compareTo(left.recordedAt));

    final limitedRecords = records.length <= _maximumRecordCount
        ? records
        : records.take(_maximumRecordCount).toList(growable: false);

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(
        limitedRecords.map((record) => record.toJson()).toList(growable: false),
      ),
    );
  }
}
