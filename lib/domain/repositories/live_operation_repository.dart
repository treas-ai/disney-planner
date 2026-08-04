import '../entities/live_operation_snapshot.dart';

abstract interface class LiveOperationRepository {
  Future<LiveOperationSnapshot> fetchSnapshot({required String parkId});
}
