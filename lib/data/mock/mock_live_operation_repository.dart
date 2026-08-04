import '../../domain/entities/live_operation_snapshot.dart';
import '../../domain/repositories/live_operation_repository.dart';
import '../providers/mock_live_data_provider.dart';
import '../repositories/live_operation_repository_impl.dart';

class MockLiveOperationRepository implements LiveOperationRepository {
  const MockLiveOperationRepository();

  @override
  Future<LiveOperationSnapshot> fetchSnapshot({required String parkId}) {
    const repository = LiveOperationRepositoryImpl(
      provider: MockLiveDataProvider(),
    );
    return repository.fetchSnapshot(parkId: parkId);
  }
}
