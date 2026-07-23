import 'package:flutter/foundation.dart';

import '../../app/dependency/service_locator.dart';
import '../../domain/entities/facility.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/repositories/facility_repository.dart';

class FacilityController extends ChangeNotifier {
  FacilityController({
    FacilityRepository? facilityRepository,
    String initialParkId = 'tokyo_disneysea',
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
  String? selectedAreaId;
  String searchKeyword = '';

  String _selectedParkId;

  String get selectedParkId => _selectedParkId;

  List<Facility> get facilities {
    return List<Facility>.unmodifiable(_facilities);
  }

  List<Facility> get parkFacilities {
    return _facilities
        .where((facility) => facility.parkId == _selectedParkId)
        .toList(growable: false);
  }

  List<String> get availableAreaIds {
    final areaIds = parkFacilities
        .map((facility) => facility.areaId)
        .where((areaId) => areaId.isNotEmpty)
        .toSet()
        .toList();

    areaIds.sort((first, second) {
      final firstOrder = _areaDisplayOrder(first);

      final secondOrder = _areaDisplayOrder(second);

      final orderComparison = firstOrder.compareTo(secondOrder);

      if (orderComparison != 0) {
        return orderComparison;
      }

      return first.compareTo(second);
    });

    return List<String>.unmodifiable(areaIds);
  }

  List<Facility> get filteredFacilities {
    final keyword = searchKeyword.trim().toLowerCase();

    final filtered = _facilities
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

    filtered.sort((first, second) {
      final areaComparison = _areaDisplayOrder(
        first.areaId,
      ).compareTo(_areaDisplayOrder(second.areaId));

      if (areaComparison != 0) {
        return areaComparison;
      }

      final displayOrderComparison = first.displayOrder.compareTo(
        second.displayOrder,
      );

      if (displayOrderComparison != 0) {
        return displayOrderComparison;
      }

      return first.name.compareTo(second.name);
    });

    return filtered;
  }

  Future<void> loadFacilities() async {
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      _facilities = await _facilityRepository.getFacilities();

      _normalizeSelectedArea();
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

  void selectPark(String parkId) {
    if (_selectedParkId == parkId) {
      return;
    }

    _selectedParkId = parkId;
    selectedCategory = null;
    selectedAreaId = null;
    searchKeyword = '';

    notifyListeners();
  }

  void selectCategory(FacilityCategory? category) {
    if (selectedCategory == category) {
      return;
    }

    selectedCategory = category;

    notifyListeners();
  }

  void selectArea(String? areaId) {
    if (selectedAreaId == areaId) {
      return;
    }

    if (areaId != null && !availableAreaIds.contains(areaId)) {
      return;
    }

    selectedAreaId = areaId;

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
    selectedCategory = null;
    selectedAreaId = null;
    searchKeyword = '';

    notifyListeners();
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
      'tds_arabian_coast' => 'アラビアンコースト',
      'tds_mermaid_lagoon' => 'マーメイドラグーン',
      'tds_mysterious_island' => 'ミステリアスアイランド',
      'tds_fantasy_springs' => 'ファンタジースプリングス',
      _ => areaId,
    };
  }

  int _areaDisplayOrder(String areaId) {
    return switch (areaId) {
      'tdl_world_bazaar' => 10,
      'tdl_adventureland' => 20,
      'tdl_westernland' => 30,
      'tdl_critter_country' => 40,
      'tdl_fantasyland' => 50,
      'tdl_new_fantasyland' => 60,
      'tdl_toontown' => 70,
      'tdl_tomorrowland' => 80,
      'tds_mediterranean_harbor' => 110,
      'tds_american_waterfront' => 120,
      'tds_port_discovery' => 130,
      'tds_lost_river_delta' => 140,
      'tds_arabian_coast' => 150,
      'tds_mermaid_lagoon' => 160,
      'tds_mysterious_island' => 170,
      'tds_fantasy_springs' => 180,
      _ => 9999,
    };
  }

  void _normalizeSelectedArea() {
    final areaId = selectedAreaId;

    if (areaId == null) {
      return;
    }

    if (!availableAreaIds.contains(areaId)) {
      selectedAreaId = null;
    }
  }
}
