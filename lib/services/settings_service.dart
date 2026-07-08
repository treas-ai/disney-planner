import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/park_settings.dart';

class SettingsService {
  static const String _settingsKey = 'park_settings';

  Future<void> saveSettings(ParkSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(settings.toJson());

    await prefs.setString(_settingsKey, jsonString);
  }

  Future<ParkSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_settingsKey);

    if (jsonString == null) {
      return const ParkSettings(
        park: '東京ディズニーランド',
        entryTime: '09:00',
        leaveTime: '21:00',
        people: 2,
        happyEntry: false,
        useDpa: false,
        usePriorityPass: true,
        useSingleRider: false,
        lunch: true,
        dinner: true,
        rainMode: false,
        hasChildren: false,
      );
    }

    final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
    return ParkSettings.fromJson(jsonMap);
  }
}