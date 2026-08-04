import 'package:flutter/foundation.dart';

import '../../app/dependency/service_locator.dart';
import '../../core/utils/japanese_search_normalizer.dart';
import '../../domain/entities/facility.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/enums/facility_operating_status.dart';
import '../../domain/repositories/facility_repository.dart';
import 'facility_operating_filter.dart';
import 'facility_sort_type.dart';

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

  FacilityOperatingFilter selectedOperatingFilter = FacilityOperatingFilter.all;

  FacilitySortType selectedSortType = FacilitySortType.areaOrder;

  String _selectedParkId;

  String get selectedParkId {
    return _selectedParkId;
  }

  List<Facility> get facilities {
    return List<Facility>.unmodifiable(_facilities);
  }

  List<Facility> get parkFacilities {
    final result = _facilities
        .where((facility) => facility.parkId == _selectedParkId)
        .toList(growable: false);

    result.sort(_compareByArea);

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

  int get operatingFacilityCount {
    return parkFacilities.where(_isOperatingFacility).length;
  }

  int get closedFacilityCount {
    return parkFacilities.where(_isClosedFacility).length;
  }

  int get permanentlyClosedFacilityCount {
    return parkFacilities.where(_isPermanentlyClosedFacility).length;
  }

  bool get hasActiveFilters {
    return selectedAreaId != null ||
        selectedCategory != null ||
        selectedOperatingFilter != FacilityOperatingFilter.all ||
        searchKeyword.trim().isNotEmpty;
  }

  bool get isDefaultSort {
    return selectedSortType == FacilitySortType.areaOrder;
  }

  List<Facility> visibleFacilities({
    required bool Function(String facilityId) isSelected,
  }) {
    final result = _facilities
        .where((facility) {
          final matchesPark = facility.parkId == _selectedParkId;

          final matchesArea =
              selectedAreaId == null || facility.areaId == selectedAreaId;

          final matchesCategory = _matchesSelectedCategory(facility);

          final matchesOperatingStatus = _matchesSelectedOperatingFilter(
            facility,
          );

          final matchesKeyword = _matchesSearchKeyword(facility);

          return matchesPark &&
              matchesArea &&
              matchesCategory &&
              matchesOperatingStatus &&
              matchesKeyword;
        })
        .toList(growable: true);

    result.sort((left, right) {
      return _compareFacilities(
        left: left,
        right: right,
        isSelected: isSelected,
      );
    });

    return List<Facility>.unmodifiable(result);
  }

  List<Facility> get filteredFacilities {
    return visibleFacilities(isSelected: (_) => false);
  }

  Future<void> loadFacilities() async {
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      debugPrint('施設データ読み込み開始');

      _facilities = await _facilityRepository.getFacilities();

      debugPrint('施設データ読み込み完了：${_facilities.length}件');

      debugPrint('選択中のパーク：$_selectedParkId');

      debugPrint('選択中パークの施設数：${parkFacilities.length}件');
    } catch (error, stackTrace) {
      debugPrint('施設データの読み込みに失敗しました: $error');

      debugPrintStack(stackTrace: stackTrace);

      errorMessage = '施設データの読み込みに失敗しました。';
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  void selectPark(String parkId) {
    if (parkId.trim().isEmpty || _selectedParkId == parkId) {
      return;
    }

    _selectedParkId = parkId;
    selectedAreaId = null;
    selectedCategory = null;
    selectedOperatingFilter = FacilityOperatingFilter.all;
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
    final normalizedCategory = category == FacilityCategory.parade
        ? FacilityCategory.show
        : category;

    if (selectedCategory == normalizedCategory) {
      return;
    }

    selectedCategory = normalizedCategory;

    notifyListeners();
  }

  void selectOperatingFilter(FacilityOperatingFilter filter) {
    if (selectedOperatingFilter == filter) {
      return;
    }

    selectedOperatingFilter = filter;

    notifyListeners();
  }

  void selectSortType(FacilitySortType sortType) {
    if (selectedSortType == sortType) {
      return;
    }

    selectedSortType = sortType;

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
    selectedOperatingFilter = FacilityOperatingFilter.all;
    searchKeyword = '';

    if (hadActiveFilters) {
      notifyListeners();
    }
  }

  void resetSort() {
    if (isDefaultSort) {
      return;
    }

    selectedSortType = FacilitySortType.areaOrder;

    notifyListeners();
  }

  void resetFiltersAndSort() {
    final shouldNotify = hasActiveFilters || !isDefaultSort;

    selectedAreaId = null;
    selectedCategory = null;
    selectedOperatingFilter = FacilityOperatingFilter.all;
    selectedSortType = FacilitySortType.areaOrder;
    searchKeyword = '';

    if (shouldNotify) {
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
      'tdl_resort_hotels' => 'ディズニーホテル',
      'tds_mediterranean_harbor' => 'メディテレーニアンハーバー',
      'tds_american_waterfront' => 'アメリカンウォーターフロント',
      'tds_port_discovery' => 'ポートディスカバリー',
      'tds_lost_river_delta' => 'ロストリバーデルタ',
      'tds_fantasy_springs' => 'ファンタジースプリングス',
      'tds_arabian_coast' => 'アラビアンコースト',
      'tds_mermaid_lagoon' => 'マーメイドラグーン',
      'tds_mysterious_island' => 'ミステリアスアイランド',
      'tds_parkwide' => 'パークワイド',
      'tds_resort_hotels' => 'ディズニーホテル',
      'tds_park_entrance' => 'パークエントランス',
      _ => areaId,
    };
  }

  Future<void> reload() async {
    await loadFacilities();
  }

  bool _matchesSelectedCategory(Facility facility) {
    final category = selectedCategory;

    if (category == null) {
      return true;
    }

    if (category == FacilityCategory.show) {
      return facility.category == FacilityCategory.show ||
          facility.category == FacilityCategory.parade;
    }

    return facility.category == category;
  }

  bool _matchesSelectedOperatingFilter(Facility facility) {
    return switch (selectedOperatingFilter) {
      FacilityOperatingFilter.all => true,
      FacilityOperatingFilter.operatingOnly => _isOperatingFacility(facility),
      FacilityOperatingFilter.closedOnly => _isClosedFacility(facility),
      FacilityOperatingFilter.permanentlyClosedOnly =>
        _isPermanentlyClosedFacility(facility),
    };
  }

  bool _isOperatingFacility(Facility facility) {
    return facility.isOpen &&
        facility.operatingStatus == FacilityOperatingStatus.operating;
  }

  bool _isClosedFacility(Facility facility) {
    return switch (facility.operatingStatus) {
      FacilityOperatingStatus.scheduledClosure => true,
      FacilityOperatingStatus.temporarilyClosed => true,
      FacilityOperatingStatus.seasonalClosed => true,
      FacilityOperatingStatus.longTermClosed => true,
      FacilityOperatingStatus.operating => !facility.isOpen,
      FacilityOperatingStatus.permanentlyClosed => false,
    };
  }

  bool _isPermanentlyClosedFacility(Facility facility) {
    return facility.operatingStatus ==
        FacilityOperatingStatus.permanentlyClosed;
  }

  bool _matchesSearchKeyword(Facility facility) {
    final keyword = searchKeyword.trim();

    if (keyword.isEmpty) {
      return true;
    }

    final searchTargets = <String>[
      facility.name,
      facility.description ?? '',
      facility.category.label,
      _categorySearchLabel(facility),
      areaLabel(facility.areaId),
      facility.operatingStatusDisplayLabel,
      facility.operatingStatusNote ?? '',
      facility.id,
      facility.areaId,
    ];

    return JapaneseSearchNormalizer.matchesAny(
      query: keyword,
      targets: searchTargets,
    );
  }

  String _categorySearchLabel(Facility facility) {
    if (facility.category == FacilityCategory.show ||
        facility.category == FacilityCategory.parade) {
      return 'ショー・パレード ショー パレード';
    }

    return facility.category.label;
  }

  int _compareFacilities({
    required Facility left,
    required Facility right,
    required bool Function(String facilityId) isSelected,
  }) {
    return switch (selectedSortType) {
      FacilitySortType.areaOrder => _compareByArea(left, right),
      FacilitySortType.nameOrder => _compareByName(left, right),
      FacilitySortType.categoryOrder => _compareByCategory(left, right),
      FacilitySortType.operatingStatusOrder => _compareByOperatingStatus(
        left,
        right,
      ),
      FacilitySortType.selectedFirst => _compareSelectedFirst(
        left: left,
        right: right,
        isSelected: isSelected,
      ),
    };
  }

  int _compareSelectedFirst({
    required Facility left,
    required Facility right,
    required bool Function(String facilityId) isSelected,
  }) {
    final leftSelected = isSelected(left.id);
    final rightSelected = isSelected(right.id);

    if (leftSelected != rightSelected) {
      return leftSelected ? -1 : 1;
    }

    return _compareByArea(left, right);
  }

  int _compareByArea(Facility left, Facility right) {
    final leftAreaOrder = _areaDisplayOrder(left.areaId);

    final rightAreaOrder = _areaDisplayOrder(right.areaId);

    final areaOrderComparison = leftAreaOrder.compareTo(rightAreaOrder);

    if (areaOrderComparison != 0) {
      return areaOrderComparison;
    }

    final areaLabelComparison = areaLabel(
      left.areaId,
    ).compareTo(areaLabel(right.areaId));

    if (areaLabelComparison != 0) {
      return areaLabelComparison;
    }

    final displayOrderComparison = left.displayOrder.compareTo(
      right.displayOrder,
    );

    if (displayOrderComparison != 0) {
      return displayOrderComparison;
    }

    return _compareByName(left, right);
  }

  int _compareByName(Facility left, Facility right) {
    final nameComparison = left.name.compareTo(right.name);

    if (nameComparison != 0) {
      return nameComparison;
    }

    return left.id.compareTo(right.id);
  }

  int _compareByCategory(Facility left, Facility right) {
    final leftOrder = _categoryDisplayOrder(left.category);

    final rightOrder = _categoryDisplayOrder(right.category);

    final categoryComparison = leftOrder.compareTo(rightOrder);

    if (categoryComparison != 0) {
      return categoryComparison;
    }

    return _compareByArea(left, right);
  }

  int _compareByOperatingStatus(Facility left, Facility right) {
    final leftOrder = _operatingStatusDisplayOrder(left);

    final rightOrder = _operatingStatusDisplayOrder(right);

    final statusComparison = leftOrder.compareTo(rightOrder);

    if (statusComparison != 0) {
      return statusComparison;
    }

    return _compareByArea(left, right);
  }

  int _categoryDisplayOrder(FacilityCategory category) {
    return switch (category.name) {
      'attraction' => 1,
      'restaurant' => 2,
      'show' => 3,
      'parade' => 3,
      'greeting' => 4,
      'shop' => 5,
      'service' => 6,
      _ => 999,
    };
  }

  int _operatingStatusDisplayOrder(Facility facility) {
    if (_isOperatingFacility(facility)) {
      return 1;
    }

    return switch (facility.operatingStatus) {
      FacilityOperatingStatus.temporarilyClosed => 2,
      FacilityOperatingStatus.scheduledClosure => 3,
      FacilityOperatingStatus.seasonalClosed => 4,
      FacilityOperatingStatus.longTermClosed => 5,
      FacilityOperatingStatus.operating => 6,
      FacilityOperatingStatus.permanentlyClosed => 7,
    };
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
}
