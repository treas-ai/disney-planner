import '../../domain/entities/live_operating_status.dart';
import '../../domain/entities/live_pass_status.dart';
import '../../domain/entities/live_wait_time.dart';
import '../../domain/repositories/live_data_repository.dart';

class ApiLiveDataRepository implements LiveDataRepository {
  const ApiLiveDataRepository();

  Never _notImplemented() {
    throw UnsupportedError('APIリアルタイムデータはv3.0で実装します。');
  }

  @override
  Future<List<LiveWaitTime>> fetchWaitTimes({required String parkId}) {
    return _notImplemented();
  }

  @override
  Future<List<LiveOperatingStatus>> fetchOperatingStatuses({
    required String parkId,
  }) {
    return _notImplemented();
  }

  @override
  Future<List<LivePassStatus>> fetchPassStatuses({required String parkId}) {
    return _notImplemented();
  }
}
