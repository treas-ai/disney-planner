import 'package:flutter/foundation.dart';

import '../../data/local/local_history_repository.dart';
import '../../data/local/local_live_wait_time_repository.dart';
import '../../domain/entities/activity_history_record.dart';
import '../../domain/entities/live_wait_time.dart';
import '../../domain/enums/history_data_quality.dart';
import '../../domain/enums/history_data_source.dart';
import '../../domain/repositories/history_repository.dart';
import '../../domain/repositories/live_wait_time_repository.dart';

class LiveWaitTimeController extends ChangeNotifier {
  LiveWaitTimeController({
    LiveWaitTimeRepository? repository,
    HistoryRepository? historyRepository,
  }) : _repository = repository ?? const LocalLiveWaitTimeRepository(),
       _historyRepository = historyRepository ?? const LocalHistoryRepository();

  final LiveWaitTimeRepository _repository;
  final HistoryRepository _historyRepository;

  final Map<String, LiveWaitTime> _waitTimesByFacilityId = {};

  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  List<LiveWaitTime> get waitTimes {
    final values = _waitTimesByFacilityId.values.toList(growable: false);

    values.sort((left, right) {
      return right.updatedAt.compareTo(left.updatedAt);
    });

    return List<LiveWaitTime>.unmodifiable(values);
  }

  bool get hasWaitTimes {
    return _waitTimesByFacilityId.isNotEmpty;
  }

  Future<void> loadAll() async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      final loadedWaitTimes = await _repository.loadAll();

      _waitTimesByFacilityId
        ..clear()
        ..addEntries(
          loadedWaitTimes.map(
            (waitTime) => MapEntry(waitTime.facilityId, waitTime),
          ),
        );
    } catch (error, stackTrace) {
      debugPrint('待ち時間情報の読み込みに失敗しました: $error');

      debugPrintStack(stackTrace: stackTrace);

      errorMessage = '待ち時間情報を読み込めませんでした。';
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<void> loadForPark(String parkId) async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      final loadedWaitTimes = await _repository.loadForPark(parkId);

      _waitTimesByFacilityId
        ..clear()
        ..addEntries(
          loadedWaitTimes.map(
            (waitTime) => MapEntry(waitTime.facilityId, waitTime),
          ),
        );
    } catch (error, stackTrace) {
      debugPrint('パークの待ち時間情報を読み込めませんでした: $error');

      debugPrintStack(stackTrace: stackTrace);

      errorMessage = '待ち時間情報を読み込めませんでした。';
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  LiveWaitTime? waitTimeForFacility(String? facilityId) {
    if (facilityId == null || facilityId.trim().isEmpty) {
      return null;
    }

    return _waitTimesByFacilityId[facilityId];
  }

  int? waitMinutesForFacility(String? facilityId) {
    return waitTimeForFacility(facilityId)?.waitMinutes;
  }

  bool hasWaitTimeForFacility(String? facilityId) {
    return waitTimeForFacility(facilityId) != null;
  }

  bool isWaitTimeStale(
    String? facilityId, {
    DateTime? now,
    Duration staleAfter = const Duration(minutes: 30),
  }) {
    final waitTime = waitTimeForFacility(facilityId);

    if (waitTime == null) {
      return false;
    }

    return waitTime.isStaleAt(now ?? DateTime.now(), staleAfter: staleAfter);
  }

  Future<bool> updateWaitTime({
    required String facilityId,
    required String parkId,
    required int waitMinutes,
    DateTime? updatedAt,
  }) async {
    final normalizedFacilityId = facilityId.trim();

    final normalizedParkId = parkId.trim();

    if (normalizedFacilityId.isEmpty || normalizedParkId.isEmpty) {
      errorMessage = '施設またはパークの情報が不正です。';

      notifyListeners();

      return false;
    }

    if (waitMinutes < 0 || waitMinutes > 999) {
      errorMessage = '待ち時間は0〜999分で入力してください。';

      notifyListeners();

      return false;
    }

    isSaving = true;
    errorMessage = null;

    notifyListeners();

    final waitTime = LiveWaitTime(
      facilityId: normalizedFacilityId,
      parkId: normalizedParkId,
      waitMinutes: waitMinutes,
      updatedAt: updatedAt ?? DateTime.now(),
      source: LiveWaitTimeSource.manual,
    );

    final previousValue = _waitTimesByFacilityId[normalizedFacilityId];

    _waitTimesByFacilityId[normalizedFacilityId] = waitTime;

    notifyListeners();

    try {
      await _repository.save(waitTime);
      await _saveWaitTimeHistory(waitTime);

      return true;
    } catch (error, stackTrace) {
      debugPrint('待ち時間情報の保存に失敗しました: $error');

      debugPrintStack(stackTrace: stackTrace);

      if (previousValue == null) {
        _waitTimesByFacilityId.remove(normalizedFacilityId);
      } else {
        _waitTimesByFacilityId[normalizedFacilityId] = previousValue;
      }

      errorMessage = '待ち時間情報を保存できませんでした。';

      return false;
    } finally {
      isSaving = false;

      notifyListeners();
    }
  }

  Future<void> _saveWaitTimeHistory(LiveWaitTime waitTime) async {
    final recordedAt = waitTime.updatedAt;
    final record = ActivityHistoryRecord.waitTime(
      id: 'wait_${waitTime.parkId}_${waitTime.facilityId}_${recordedAt.microsecondsSinceEpoch}',
      parkId: waitTime.parkId,
      facilityId: waitTime.facilityId,
      waitMinutes: waitTime.waitMinutes,
      recordedAt: recordedAt,
      source: switch (waitTime.source) {
        LiveWaitTimeSource.manual => HistoryDataSource.manual,
        LiveWaitTimeSource.realtime => HistoryDataSource.officialReference,
        LiveWaitTimeSource.estimated => HistoryDataSource.predicted,
      },
      quality: waitTime.source == LiveWaitTimeSource.estimated
          ? HistoryDataQuality.low
          : HistoryDataQuality.high,
    );

    try {
      await _historyRepository.save(record);
    } catch (error, stackTrace) {
      debugPrint('AI学習用の待ち時間履歴を保存できませんでした: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> removeWaitTime(String facilityId) async {
    final normalizedFacilityId = facilityId.trim();

    if (normalizedFacilityId.isEmpty) {
      return false;
    }

    final previousValue = _waitTimesByFacilityId[normalizedFacilityId];

    if (previousValue == null) {
      return true;
    }

    isSaving = true;
    errorMessage = null;

    _waitTimesByFacilityId.remove(normalizedFacilityId);

    notifyListeners();

    try {
      await _repository.remove(normalizedFacilityId);

      return true;
    } catch (error, stackTrace) {
      debugPrint('待ち時間情報の削除に失敗しました: $error');

      debugPrintStack(stackTrace: stackTrace);

      _waitTimesByFacilityId[normalizedFacilityId] = previousValue;

      errorMessage = '待ち時間情報を削除できませんでした。';

      return false;
    } finally {
      isSaving = false;

      notifyListeners();
    }
  }

  Future<bool> clearForPark(String parkId) async {
    final normalizedParkId = parkId.trim();

    if (normalizedParkId.isEmpty) {
      return false;
    }

    final previousValues = Map<String, LiveWaitTime>.of(_waitTimesByFacilityId);

    isSaving = true;
    errorMessage = null;

    _waitTimesByFacilityId.removeWhere(
      (_, waitTime) => waitTime.parkId == normalizedParkId,
    );

    notifyListeners();

    try {
      await _repository.clearForPark(normalizedParkId);

      return true;
    } catch (error, stackTrace) {
      debugPrint('パークの待ち時間情報を削除できませんでした: $error');

      debugPrintStack(stackTrace: stackTrace);

      _waitTimesByFacilityId
        ..clear()
        ..addAll(previousValues);

      errorMessage = '待ち時間情報を削除できませんでした。';

      return false;
    } finally {
      isSaving = false;

      notifyListeners();
    }
  }

  void clearError() {
    if (errorMessage == null) {
      return;
    }

    errorMessage = null;

    notifyListeners();
  }
}
