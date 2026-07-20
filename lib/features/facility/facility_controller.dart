import 'package:flutter/foundation.dart';

import '../../app/dependency/service_locator.dart';
import '../../domain/entities/facility.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/repositories/facility_repository.dart';

class FacilityController extends ChangeNotifier {
  FacilityController({FacilityRepository? facilityRepository})
    : _facilityRepository =
          facilityRepository ?? ServiceLocator.facilityRepository {
    loadFacilities();
  }

  final FacilityRepository _facilityRepository;

  bool isLoading = false;
  String? errorMessage;

  List<Facility> _facilities = [];

  FacilityCategory? selectedCategory;
  String searchKeyword = '';

  List<Facility> get facilities => List.unmodifiable(_facilities);

  List<Facility> get filteredFacilities {
    return _facilities.where((facility) {
      final matchesCategory =
          selectedCategory == null || facility.category == selectedCategory;

      final keyword = searchKeyword.trim().toLowerCase();

      final matchesKeyword =
          keyword.isEmpty ||
          facility.name.toLowerCase().contains(keyword) ||
          (facility.description?.toLowerCase().contains(keyword) ?? false) ||
          facility.category.label.toLowerCase().contains(keyword);

      return matchesCategory && matchesKeyword;
    }).toList();
  }

  Future<void> loadFacilities() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _facilities = await _facilityRepository.getFacilities();
    } catch (_) {
      errorMessage = '施設データの読み込みに失敗しました。';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectCategory(FacilityCategory? category) {
    selectedCategory = category;
    notifyListeners();
  }

  void updateSearchKeyword(String value) {
    searchKeyword = value;
    notifyListeners();
  }
}
