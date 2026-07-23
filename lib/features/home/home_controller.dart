import 'package:flutter/foundation.dart';

import '../../app/dependency/service_locator.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/park.dart';
import '../../domain/entities/resort.dart';
import '../../domain/repositories/facility_repository.dart';
import '../../domain/repositories/park_repository.dart';

class HomeController extends ChangeNotifier {
  HomeController({
    ParkRepository? parkRepository,
    FacilityRepository? facilityRepository,
  }) : _parkRepository = parkRepository ?? ServiceLocator.parkRepository,
       _facilityRepository =
           facilityRepository ?? ServiceLocator.facilityRepository {
    loadHomeData();
  }

  final ParkRepository _parkRepository;
  final FacilityRepository _facilityRepository;

  bool isLoading = false;
  String? errorMessage;

  List<Resort> resorts = [];
  List<Park> parks = [];
  List<Facility> facilities = [];

  Future<void> loadHomeData() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      debugPrint('ホームデータ読み込み開始');

      resorts = await _parkRepository.getResorts();

      debugPrint('リゾート読み込み完了：${resorts.length}件');

      parks = await _parkRepository.getParks();

      debugPrint('パーク読み込み完了：${parks.length}件');

      facilities = await _facilityRepository.getFacilities();

      debugPrint('施設読み込み完了：${facilities.length}件');

      debugPrint('ホームデータ読み込み完了');
    } catch (error, stackTrace) {
      debugPrint('ホームデータの読み込みに失敗しました: $error');

      debugPrintStack(stackTrace: stackTrace);

      errorMessage =
          'ホームデータの読み込みに失敗しました。\n'
          '$error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
