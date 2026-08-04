import '../entities/live_operation_snapshot.dart';
import '../enums/live_data_source_type.dart';

abstract interface class LiveDataProvider {
  LiveDataSourceType get sourceType;

  Future<LiveOperationSnapshot> fetchSnapshot({required String parkId});
}

class LiveDataProviderException implements Exception {
  const LiveDataProviderException(this.message);

  final String message;

  @override
  String toString() => 'LiveDataProviderException: $message';
}
