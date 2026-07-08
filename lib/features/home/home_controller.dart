import 'package:flutter/foundation.dart';

import '../../data/datasources/mock/mock_facility_data_source.dart';
import '../../data/datasources/mock/mock_park_data_source.dart';
import '../../data/repositories/facility_repository_impl.dart';
import '../../data/repositories/park_repository_impl.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/park.dart';
import '../../domain/entities/resort.dart';

class HomeController extends ChangeNotifier {
  HomeController() {
    _initializeRepositories();
    loadHomeData();
  }

  late final ParkRepositoryImpl _parkRepository;
  late final FacilityRepositoryImpl _facilityRepository;

  bool isLoading = false;
  String? errorMessage;

  List<Resort> resorts = [];
  List<Park> parks = [];
  List<Facility> facilities = [];

  void _initializeRepositories() {
    final parkDataSource = MockParkDataSource();
    final facilityDataSource = MockFacilityDataSource();

    _parkRepository = ParkRepositoryImpl(dataSource: parkDataSource);
    _facilityRepository = FacilityRepositoryImpl(dataSource: facilityDataSource);
  }

  Future<void> loadHomeData() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      resorts = await _parkRepository.getResorts();
      parks = await _parkRepository.getParks();
      facilities = await _facilityRepository.getFacilities();
    } catch (error) {
      errorMessage = 'ホームデータの読み込みに失敗しました。';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}