import '../../domain/entities/live_operation_snapshot.dart';
import '../../domain/enums/live_data_source_type.dart';
import '../../domain/providers/live_data_provider.dart';

class OfficialLiveDataProvider implements LiveDataProvider {
  const OfficialLiveDataProvider();

  @override
  LiveDataSourceType get sourceType => LiveDataSourceType.official;

  @override
  Future<LiveOperationSnapshot> fetchSnapshot({required String parkId}) {
    throw const LiveDataProviderException(
      '自動取得の接続先はまだ設定されていません。',
    );
  }
}
