import 'package:flutter/foundation.dart';

import '../../app/dependency/service_locator.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/manual_wait_time_entry.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/enums/live_data_source_type.dart';
import '../../domain/enums/live_operation_availability.dart';

class ManualLiveDataController extends ChangeNotifier {
  ManualLiveDataController({required this.parkId});

  final String parkId;

  bool isLoading = false;
  String? errorMessage;
  List<Facility> facilities = const [];
  Map<String, ManualWaitTimeEntry> entries = const {};

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final allFacilities = await ServiceLocator.facilityRepository
          .getFacilitiesByParkId(parkId);
      final saved = await ServiceLocator.manualWaitTimeStore.loadForPark(
        parkId,
      );

      facilities =
          allFacilities
              .where(
                (facility) => facility.category == FacilityCategory.attraction,
              )
              .toList(growable: false)
            ..sort((left, right) => left.name.compareTo(right.name));
      entries = {for (final entry in saved) entry.facilityId: entry};
    } catch (error, stackTrace) {
      debugPrint('手動待ち時間データの読み込みに失敗しました: $error');
      debugPrintStack(stackTrace: stackTrace);
      errorMessage = '手動入力データを読み込めませんでした。';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> save({
    required String facilityId,
    required LiveOperationAvailability availability,
    int? standbyMinutes,
  }) async {
    final entry = ManualWaitTimeEntry(
      parkId: parkId,
      facilityId: facilityId,
      availability: availability,
      updatedAt: DateTime.now(),
      standbyMinutes: availability == LiveOperationAvailability.operating
          ? standbyMinutes
          : null,
    );

    await ServiceLocator.manualWaitTimeStore.save(entry);
    await ServiceLocator.liveDataSourcePreferences.save(
      LiveDataSourceType.manual,
    );
    ServiceLocator.clearLiveDataCache();
    await load();
  }

  Future<void> delete(String facilityId) async {
    await ServiceLocator.manualWaitTimeStore.delete(
      parkId: parkId,
      facilityId: facilityId,
    );
    ServiceLocator.clearLiveDataCache();
    await load();
  }

  Future<void> clearAll() async {
    await ServiceLocator.manualWaitTimeStore.clearPark(parkId);
    ServiceLocator.clearLiveDataCache();
    await load();
  }
}
