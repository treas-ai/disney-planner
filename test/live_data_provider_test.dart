import 'package:disney_planner/data/providers/cached_live_data_provider.dart';
import 'package:disney_planner/data/providers/mock_live_data_provider.dart';
import 'package:disney_planner/data/providers/official_live_data_provider.dart';
import 'package:disney_planner/domain/enums/live_data_source_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mock provider returns mock source snapshot', () async {
    const provider = MockLiveDataProvider();

    final snapshot = await provider.fetchSnapshot(parkId: 'tokyo_disneysea');

    expect(snapshot.sourceType, LiveDataSourceType.mock);
    expect(snapshot.isMock, isTrue);
    expect(snapshot.hasData, isTrue);
  });

  test(
    'official provider falls back to mock when connector is unavailable',
    () async {
      final provider = CachedLiveDataProvider(
        primary: const OfficialLiveDataProvider(),
        fallback: const MockLiveDataProvider(),
        cache: LiveDataMemoryCache(),
      );

      final snapshot = await provider.fetchSnapshot(parkId: 'tokyo_disneyland');

      expect(snapshot.isMock, isTrue);
      expect(snapshot.fallbackMessage, isNotNull);
    },
  );

  test('cached provider reuses primary snapshot within ttl', () async {
    final cache = LiveDataMemoryCache();
    final provider = CachedLiveDataProvider(
      primary: const MockLiveDataProvider(),
      fallback: const MockLiveDataProvider(),
      cache: cache,
    );

    final first = await provider.fetchSnapshot(parkId: 'tokyo_disneysea');
    final second = await provider.fetchSnapshot(parkId: 'tokyo_disneysea');

    expect(first.parkId, second.parkId);
    expect(second.hasData, isTrue);
  });
}
