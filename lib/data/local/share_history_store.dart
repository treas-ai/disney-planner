import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/share_import_record.dart';

class ShareHistoryStore {
  const ShareHistoryStore();

  static const _key = 'share_import_history_v1';

  Future<List<ShareImportRecord>> load() async {
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
          (item) => ShareImportRecord.fromJson(Map<String, Object?>.from(item)),
        )
        .toList(growable: false);
  }

  Future<void> add(ShareImportRecord record) async {
    final current = [...await load()];
    current.insert(0, record);
    if (current.length > 10) {
      current.removeRange(10, current.length);
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(current.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }
}
