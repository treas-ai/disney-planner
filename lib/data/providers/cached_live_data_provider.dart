import '../../domain/entities/live_operation_snapshot.dart';
import '../../domain/enums/live_data_source_type.dart';
import '../../domain/providers/live_data_provider.dart';

class LiveDataMemoryCache {
  final Map<String, _CacheEntry> _entries = {};

  LiveOperationSnapshot? read(String key, Duration ttl) {
    final entry = _entries[key];
    if (entry == null) {
      return null;
    }

    if (DateTime.now().difference(entry.savedAt) > ttl) {
      _entries.remove(key);
      return null;
    }

    return entry.snapshot;
  }

  void write(String key, LiveOperationSnapshot snapshot) {
    _entries[key] = _CacheEntry(snapshot: snapshot, savedAt: DateTime.now());
  }

  void clear() => _entries.clear();
}

class CachedLiveDataProvider implements LiveDataProvider {
  const CachedLiveDataProvider({
    required this.primary,
    required this.fallback,
    required this.cache,
    this.ttl = const Duration(minutes: 5),
  });

  final LiveDataProvider primary;
  final LiveDataProvider fallback;
  final LiveDataMemoryCache cache;
  final Duration ttl;

  @override
  LiveDataSourceType get sourceType => primary.sourceType;

  @override
  Future<LiveOperationSnapshot> fetchSnapshot({required String parkId}) async {
    final cacheKey = '${primary.sourceType.name}:$parkId';

    try {
      final snapshot = await primary.fetchSnapshot(parkId: parkId);
      cache.write(cacheKey, snapshot);
      return snapshot;
    } catch (error) {
      final cached = cache.read(cacheKey, ttl);
      if (cached != null) {
        return cached.copyWith(
          fromCache: true,
          fallbackMessage: '取得に失敗したため、保存済みデータを表示しています。',
        );
      }

      final fallbackSnapshot = await fallback.fetchSnapshot(parkId: parkId);
      return fallbackSnapshot.copyWith(
        fallbackMessage:
            '自動取得の接続先が未設定のため、サンプルデータへ切り替えました。',
      );
    }
  }
}

class _CacheEntry {
  const _CacheEntry({required this.snapshot, required this.savedAt});

  final LiveOperationSnapshot snapshot;
  final DateTime savedAt;
}
