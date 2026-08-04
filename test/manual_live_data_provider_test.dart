import 'package:disney_planner/data/local/manual_wait_time_store.dart';
import 'package:disney_planner/data/providers/manual_live_data_provider.dart';
import 'package:disney_planner/domain/enums/live_data_source_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('manual provider returns manual source even when empty', () async {
    SharedPreferences.setMockInitialValues({});
    const provider = ManualLiveDataProvider(store: ManualWaitTimeStore());

    final snapshot = await provider.fetchSnapshot(parkId: 'tokyo_disneysea');

    expect(snapshot.sourceType, LiveDataSourceType.manual);
    expect(snapshot.attractions, isEmpty);
    expect(snapshot.fallbackMessage, isNotNull);
  });
}
