import 'package:shared_preferences/shared_preferences.dart';

class SelectionService {
  static String _key(String type, int id) {
    return 'selected_${type}_$id';
  }

  Future<bool?> loadSelected({
    required String type,
    required int id,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(type, id));
  }

  Future<void> saveSelected({
    required String type,
    required int id,
    required bool selected,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(type, id), selected);
  }
}