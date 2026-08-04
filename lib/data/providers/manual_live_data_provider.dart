import '../../domain/entities/attraction_operation.dart';
import '../../domain/entities/live_operation_snapshot.dart';
import '../../domain/enums/live_data_source_type.dart';
import '../../domain/providers/live_data_provider.dart';
import '../local/manual_wait_time_store.dart';

class ManualLiveDataProvider implements LiveDataProvider {
  const ManualLiveDataProvider({required this.store});

  final ManualWaitTimeStore store;

  @override
  LiveDataSourceType get sourceType => LiveDataSourceType.manual;

  @override
  Future<LiveOperationSnapshot> fetchSnapshot({required String parkId}) async {
    final entries = await store.loadForPark(parkId);
    final updatedAt = entries.isEmpty
        ? DateTime.now()
        : entries
              .map((entry) => entry.updatedAt)
              .reduce((left, right) => left.isAfter(right) ? left : right);

    return LiveOperationSnapshot(
      parkId: parkId,
      updatedAt: updatedAt,
      sourceType: LiveDataSourceType.manual,
      attractions: entries
          .map(
            (entry) => AttractionOperation(
              parkId: entry.parkId,
              facilityId: entry.facilityId,
              availability: entry.availability,
              updatedAt: entry.updatedAt,
              standbyMinutes: entry.standbyMinutes,
              note: entry.isStale ? '30分以上前の手動入力です。' : '手動入力',
            ),
          )
          .toList(growable: false),
      fallbackMessage: entries.isEmpty
          ? '手動入力データがありません。公式アプリを確認して入力してください。'
          : null,
    );
  }
}
