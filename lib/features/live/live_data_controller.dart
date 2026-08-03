import 'package:flutter/foundation.dart';

import '../../data/local/local_live_data_repository.dart';
import '../../domain/entities/live_operating_status.dart';
import '../../domain/entities/live_pass_status.dart';
import '../../domain/entities/live_wait_time.dart';
import '../../domain/repositories/live_data_repository.dart';

class LiveDataController extends ChangeNotifier {
  LiveDataController({LiveDataRepository? repository})
    : _repository = repository ?? const LocalLiveDataRepository();

  final LiveDataRepository _repository;

  final Map<String, LiveWaitTime> _waitTimes = {};
  final Map<String, LiveOperatingStatus> _operatingStatuses = {};
  final Map<String, List<LivePassStatus>> _passStatuses = {};

  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastUpdatedAt;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;

  List<LiveWaitTime> get waitTimes =>
      List<LiveWaitTime>.unmodifiable(_waitTimes.values);

  List<LiveOperatingStatus> get operatingStatuses =>
      List<LiveOperatingStatus>.unmodifiable(_operatingStatuses.values);

  List<LivePassStatus> get passStatuses => List<LivePassStatus>.unmodifiable(
    _passStatuses.values.expand((items) => items),
  );

  Future<void> loadForPark(String parkId) async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final waitTimes = await _repository.fetchWaitTimes(parkId: parkId);
      final operatingStatuses = await _repository.fetchOperatingStatuses(
        parkId: parkId,
      );
      final passStatuses = await _repository.fetchPassStatuses(parkId: parkId);

      _waitTimes
        ..clear()
        ..addEntries(waitTimes.map((item) => MapEntry(item.facilityId, item)));
      _operatingStatuses
        ..clear()
        ..addEntries(
          operatingStatuses.map((item) => MapEntry(item.facilityId, item)),
        );
      _passStatuses.clear();
      for (final item in passStatuses) {
        _passStatuses.putIfAbsent(item.facilityId, () => []).add(item);
      }

      _lastUpdatedAt = DateTime.now();
    } catch (error, stackTrace) {
      debugPrint('リアルタイムデータの読み込みに失敗しました: $error');
      debugPrintStack(stackTrace: stackTrace);
      _errorMessage = 'リアルタイムデータを読み込めませんでした。';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  LiveWaitTime? waitTimeForFacility(String? facilityId) {
    return facilityId == null ? null : _waitTimes[facilityId];
  }

  LiveOperatingStatus? operatingStatusForFacility(String? facilityId) {
    return facilityId == null ? null : _operatingStatuses[facilityId];
  }

  List<LivePassStatus> passStatusesForFacility(String? facilityId) {
    if (facilityId == null) {
      return const [];
    }
    return List<LivePassStatus>.unmodifiable(
      _passStatuses[facilityId] ?? const <LivePassStatus>[],
    );
  }
}
