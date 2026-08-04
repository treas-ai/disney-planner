import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/enums/live_data_source_type.dart';

class LiveDataSourcePreferences {
  const LiveDataSourcePreferences();

  static const _key = 'live_data_source_type';

  Future<LiveDataSourceType> load() async {
    final preferences = await SharedPreferences.getInstance();
    return LiveDataSourceType.fromName(preferences.getString(_key));
  }

  Future<void> save(LiveDataSourceType value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, value.name);
  }
}
