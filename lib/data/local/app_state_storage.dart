import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AppStateStorage {
  static const String _storageKey = 'disney_planner_app_state';

  Future<void> save(Map<String, dynamic> json) async {
    final preferences = await SharedPreferences.getInstance();
    final encodedJson = jsonEncode(json);

    await preferences.setString(_storageKey, encodedJson);
  }

  Future<Map<String, dynamic>?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encodedJson = preferences.getString(_storageKey);

    if (encodedJson == null || encodedJson.isEmpty) {
      return null;
    }

    final decodedJson = jsonDecode(encodedJson);

    if (decodedJson is Map<String, dynamic>) {
      return decodedJson;
    }

    return null;
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }
}
