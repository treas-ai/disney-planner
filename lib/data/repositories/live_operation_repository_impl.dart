import '../../domain/entities/live_operation_snapshot.dart';
import '../../domain/providers/live_data_provider.dart';
import '../../domain/repositories/live_operation_repository.dart';

class LiveOperationRepositoryImpl implements LiveOperationRepository {
  const LiveOperationRepositoryImpl({required this.provider});

  final LiveDataProvider provider;

  @override
  Future<LiveOperationSnapshot> fetchSnapshot({required String parkId}) {
    return provider.fetchSnapshot(parkId: parkId);
  }
}
