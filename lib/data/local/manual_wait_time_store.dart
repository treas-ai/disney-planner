import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/manual_wait_time_entry.dart';

class ManualWaitTimeStore {
  const ManualWaitTimeStore();

  static const _key = 'manual_wait_time_entries';

  Future<List<ManualWaitTimeEntry>> loadAll() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map(
          (item) => ManualWaitTimeEntry.fromJson(
            Map<String, Object?>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<List<ManualWaitTimeEntry>> loadForPark(String parkId) async {
    final entries = await loadAll();
    return entries
        .where((entry) => entry.parkId == parkId)
        .toList(growable: false);
  }

  Future<void> save(ManualWaitTimeEntry entry) async {
    final entries = [...await loadAll()];
    final index = entries.indexWhere(
      (item) =>
          item.parkId == entry.parkId &&
          item.facilityId == entry.facilityId,
    );

    final previous = index < 0 ? null : entries[index];
    final saved = ManualWaitTimeEntry(
      parkId: entry.parkId,
      facilityId: entry.facilityId,
      availability: entry.availability,
      updatedAt: entry.updatedAt,
      standbyMinutes: entry.standbyMinutes,
      previousStandbyMinutes: previous?.standbyMinutes,
    );

    if (index < 0) {
      entries.add(saved);
    } else {
      entries[index] = saved;
    }

    await _persist(entries);
  }

  Future<void> delete({
    required String parkId,
    required String facilityId,
  }) async {
    final entries = [...await loadAll()]
      ..removeWhere(
        (item) =>
            item.parkId == parkId &&
            item.facilityId == facilityId,
      );
    await _persist(entries);
  }

  Future<void> clearPark(String parkId) async {
    final entries = [...await loadAll()]
      ..removeWhere((item) => item.parkId == parkId);
    await _persist(entries);
  }

  Future<void> _persist(List<ManualWaitTimeEntry> entries) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }
}
