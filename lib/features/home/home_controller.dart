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
  })  : _parkRepository = parkRepository ?? ServiceLocator.parkRepository,
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
      resorts = await _parkRepository.getResorts();
      parks = await _parkRepository.getParks();
      facilities = await _facilityRepository.getFacilities();
    } catch (_) {
      errorMessage = 'ホームデータの読み込みに失敗しました。';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}