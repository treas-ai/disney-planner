import 'package:flutter/foundation.dart';

import '../../app/dependency/service_locator.dart';
import '../../domain/entities/facility.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/repositories/facility_repository.dart';

class FacilityController extends ChangeNotifier {
  FacilityController({
    FacilityRepository? facilityRepository,
    String initialParkId = 'tokyo_disneyland',
  }) : _facilityRepository =
           facilityRepository ?? ServiceLocator.facilityRepository,
       _selectedParkId = initialParkId {
    loadFacilities();
  }

  final FacilityRepository _facilityRepository;

  bool isLoading = false;
  String? errorMessage;

  List<Facility> _facilities = [];

  FacilityCategory? selectedCategory;
  String searchKeyword = '';
  String? selectedAreaId;

  String _selectedParkId;

  String get selectedParkId => _selectedParkId;

  List<Facility> get facilities {
    return List<Facility>.unmodifiable(_facilities);
  }

  List<Facility> get parkFacilities {
    final result = _facilities
        .where((facility) => facility.parkId == _selectedParkId)
        .toList(growable: false);

    result.sort(_compareFacilities);

    return List<Facility>.unmodifiable(result);
  }

  List<String> get availableParkIds {
    final parkIds = _facilities
        .map((facility) => facility.parkId)
        .where((parkId) => parkId.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);

    parkIds.sort();

    return List<String>.unmodifiable(parkIds);
  }

  List<String> get availableAreaIds {
    final areaIds = _facilities
        .where((facility) => facility.parkId == _selectedParkId)
        .map((facility) => facility.areaId)
        .where((areaId) => areaId.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);

    areaIds.sort((left, right) {
      final leftOrder = _areaDisplayOrder(left);
      final rightOrder = _areaDisplayOrder(right);

      final orderComparison = leftOrder.compareTo(rightOrder);

      if (orderComparison != 0) {
        return orderComparison;
      }

      return areaLabel(left).compareTo(areaLabel(right));
    });

    return List<String>.unmodifiable(areaIds);
  }

  bool get hasActiveFilters {
    return selectedAreaId != null ||
        selectedCategory != null ||
        searchKeyword.trim().isNotEmpty;
  }

  List<Facility> get filteredFacilities {
    final keyword = searchKeyword.trim().toLowerCase();

    final result = _facilities
        .where((facility) {
          final matchesPark = facility.parkId == _selectedParkId;

          final matchesArea =
              selectedAreaId == null || facility.areaId == selectedAreaId;

          final matchesCategory =
              selectedCategory == null || facility.category == selectedCategory;

          final matchesKeyword =
              keyword.isEmpty ||
              facility.name.toLowerCase().contains(keyword) ||
              (facility.description?.toLowerCase().contains(keyword) ??
                  false) ||
              facility.category.label.toLowerCase().contains(keyword) ||
              areaLabel(facility.areaId).toLowerCase().contains(keyword);

          return matchesPark &&
              matchesArea &&
              matchesCategory &&
              matchesKeyword;
        })
        .toList(growable: false);

    result.sort(_compareFacilities);

    return List<Facility>.unmodifiable(result);
  }

  Future<void> loadFacilities() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      debugPrint('施設データ読み込み開始');

      _facilities = await _facilityRepository.getFacilities();

      debugPrint(
        '施設データ読み込み完了：'
        '${_facilities.length}件',
      );

      _selectAvailableParkIfNecessary();

      debugPrint('選択中のパーク：$_selectedParkId');

      debugPrint(
        '選択中パークの施設数：'
        '${parkFacilities.length}件',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '施設データの読み込みに失敗しました: '
        '$error',
      );

      debugPrintStack(stackTrace: stackTrace);

      errorMessage = '施設データの読み込みに失敗しました。';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _selectAvailableParkIfNecessary() {
    if (_facilities.isEmpty) {
      return;
    }

    final selectedParkHasFacilities = _facilities.any(
      (facility) => facility.parkId == _selectedParkId,
    );

    if (selectedParkHasFacilities) {
      return;
    }

    final firstAvailableParkId = _facilities.first.parkId;

    if (firstAvailableParkId.trim().isEmpty) {
      return;
    }

    _selectedParkId = firstAvailableParkId;
    selectedAreaId = null;
    selectedCategory = null;
    searchKeyword = '';
  }

  void selectPark(String parkId) {
    if (_selectedParkId == parkId) {
      return;
    }

    _selectedParkId = parkId;
    selectedAreaId = null;
    selectedCategory = null;
    searchKeyword = '';

    notifyListeners();
  }

  void selectArea(String? areaId) {
    if (areaId == null) {
      if (selectedAreaId == null) {
        return;
      }

      selectedAreaId = null;
      notifyListeners();
      return;
    }

    if (selectedAreaId == areaId) {
      selectedAreaId = null;
    } else {
      selectedAreaId = areaId;
    }

    notifyListeners();
  }

  void selectCategory(FacilityCategory? category) {
    if (selectedCategory == category) {
      return;
    }

    selectedCategory = category;
    notifyListeners();
  }

  void updateSearchKeyword(String value) {
    if (searchKeyword == value) {
      return;
    }

    searchKeyword = value;
    notifyListeners();
  }

  void clearFilters() {
    final hadActiveFilters = hasActiveFilters;

    selectedAreaId = null;
    selectedCategory = null;
    searchKeyword = '';

    if (hadActiveFilters) {
      notifyListeners();
    }
  }

  String areaLabel(String areaId) {
    return switch (areaId) {
      'tdl_world_bazaar' => 'ワールドバザール',
      'tdl_adventureland' => 'アドベンチャーランド',
      'tdl_westernland' => 'ウエスタンランド',
      'tdl_critter_country' => 'クリッターカントリー',
      'tdl_fantasyland' => 'ファンタジーランド',
      'tdl_new_fantasyland' => 'ニューファンタジーランド',
      'tdl_toontown' => 'トゥーンタウン',
      'tdl_tomorrowland' => 'トゥモローランド',
      'tds_mediterranean_harbor' => 'メディテレーニアンハーバー',
      'tds_american_waterfront' => 'アメリカンウォーターフロント',
      'tds_port_discovery' => 'ポートディスカバリー',
      'tds_lost_river_delta' => 'ロストリバーデルタ',
      'tds_fantasy_springs' => 'ファンタジースプリングス',
      'tds_arabian_coast' => 'アラビアンコースト',
      'tds_mermaid_lagoon' => 'マーメイドラグーン',
      'tds_mysterious_island' => 'ミステリアスアイランド',
      _ => areaId,
    };
  }

  Future<void> reload() async {
    await loadFacilities();
  }

  int _areaDisplayOrder(String areaId) {
    return switch (areaId) {
      'tdl_world_bazaar' => 1,
      'tdl_adventureland' => 2,
      'tdl_westernland' => 3,
      'tdl_critter_country' => 4,
      'tdl_fantasyland' => 5,
      'tdl_new_fantasyland' => 6,
      'tdl_toontown' => 7,
      'tdl_tomorrowland' => 8,
      'tds_mediterranean_harbor' => 1,
      'tds_american_waterfront' => 2,
      'tds_port_discovery' => 3,
      'tds_lost_river_delta' => 4,
      'tds_fantasy_springs' => 5,
      'tds_arabian_coast' => 6,
      'tds_mermaid_lagoon' => 7,
      'tds_mysterious_island' => 8,
      _ => 999,
    };
  }

  int _compareFacilities(Facility left, Facility right) {
    final leftAreaOrder = _areaDisplayOrder(left.areaId);
    final rightAreaOrder = _areaDisplayOrder(right.areaId);

    final areaOrderComparison = leftAreaOrder.compareTo(rightAreaOrder);

    if (areaOrderComparison != 0) {
      return areaOrderComparison;
    }

    final areaIdComparison = left.areaId.compareTo(right.areaId);

    if (areaIdComparison != 0) {
      return areaIdComparison;
    }

    final displayOrderComparison = left.displayOrder.compareTo(
      right.displayOrder,
    );

    if (displayOrderComparison != 0) {
      return displayOrderComparison;
    }

    return left.name.compareTo(right.name);
  }
}
