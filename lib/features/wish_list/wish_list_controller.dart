import 'package:flutter/foundation.dart';

import '../../app/state/app_state.dart';
import '../../core/utils/flexible_search.dart';
import '../../core/utils/wish_search_metadata.dart';
import '../../data/repositories/wish_event_pack_repository_impl.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/wish_event_pack.dart';
import '../../domain/entities/wish_item.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/enums/dining_location_type.dart';
import '../../domain/enums/wish_item_category.dart';
import '../../domain/repositories/facility_repository.dart';
import '../../domain/repositories/wish_event_pack_repository.dart';
import '../../domain/services/wish_display_deduplicator.dart';
import '../../domain/services/wish_planning_intent_resolver.dart';

class WishListController extends ChangeNotifier {
  WishListController({
    required this.appState,
    required this.facilityRepository,
    WishEventPackRepository? eventPackRepository,
  }) : eventPackRepository =
           eventPackRepository ?? const WishEventPackRepositoryImpl();

  final AppState appState;
  final FacilityRepository facilityRepository;
  final WishEventPackRepository eventPackRepository;

  bool isLoading = false;
  bool isRefreshing = false;
  String? errorMessage;
  List<WishEventPack> packs = const [];
  List<WishItem> facilityWishItems = const [];
  Map<String, Facility> _facilityById = const {};
  WishItemCategory? categoryFilter;
  bool freeDrinkOnly = false;
  String query = '';
  bool selectedOnly = false;

  /// Wish の表示判定は「今日」ではなく来園日を優先する。
  DateTime get effectiveDate =>
      appState.tripSettings.visitDate ?? DateTime.now();

  List<WishItem> get allLoadedItems {
    final byId = <String, WishItem>{};
    for (final pack in packs.where((pack) => pack.isAvailableOn(effectiveDate))) {
      for (final item in pack.items) {
        byId[item.id] = item;
      }
    }
    for (final item in facilityWishItems) {
      byId.putIfAbsent(item.id, () => item);
    }
    return List<WishItem>.unmodifiable(byId.values);
  }

  List<WishItem> get allItems {
    return allLoadedItems
        .where(_isSelectableOnEffectiveDate)
        .toList(growable: false);
  }

  List<WishItem> get visibleItems {
    final parkId = appState.tripSettings.parkId;
    final filtered = allItems.where((item) {
      if (item.parkId != parkId) {
        return false;
      }
      if (categoryFilter != null && item.category != categoryFilter) {
        return false;
      }
      if (selectedOnly && !appState.wishStateFor(item.id).selected) return false;
      if (freeDrinkOnly && !item.freeDrinkEligible) {
        return false;
      }
      if (query.trim().isNotEmpty &&
          !FlexibleSearch.matches(query, _searchFieldsFor(item))) {
        return false;
      }
      return true;
    });

    // Seasonal packs and the facility master can describe the same logical
    // event. Keep both records for scheduling, but show one selectable row.
    final selectedIds = <String>{
      for (final item in filtered)
        if (appState.wishStateFor(item.id).selected) item.id,
    };
    final items = WishDisplayDeduplicator.deduplicate(
      filtered,
      selectedIds: selectedIds,
    );

    // Keep the visible list position stable while the user edits importance.
    // Importance affects planning, not browsing order: re-sorting here made a row
    // jump as soon as `できれば` / `絶対行きたい` was toggled, forcing the
    // user to chase the same item before setting repeat count or conditions.
    items.sort((left, right) {
      if (query.trim().isNotEmpty) {
        final byScore = FlexibleSearch.score(query, _searchFieldsFor(right))
            .compareTo(FlexibleSearch.score(query, _searchFieldsFor(left)));
        if (byScore != 0) return byScore;
      }
      return left.name.compareTo(right.name);
    });
    return items;
  }


  Iterable<String?> _searchFieldsFor(WishItem item) sync* {
    yield item.name;
    yield item.category.label;
    yield* WishSearchMetadata.aliasesFor(item.name);
    yield* WishSearchMetadata.semanticTagsFor(item.name);
    yield* WishSearchMetadata.eventTagsFor(item.eventPackId);
    yield item.description;
    yield* item.venueNames;

    for (final facilityId in item.venueFacilityIds) {
      final facility = _facilityById[facilityId];
      if (facility == null) continue;
      yield facility.name;
      yield facility.category.label;
      yield facility.description;
      yield facility.targetAge;
      yield facility.rideType;
      yield facility.representativeMenu;
      yield facility.popcornFlavor;
      yield facility.menuNote;
      yield facility.showName;
      if (facility.isIndoor) yield '屋内 室内 indoor';
      if (facility.supportsDpa) yield 'DPA ディズニープレミアアクセス premier access';
      if (facility.supportsPriorityPass) yield 'プライオリティパス priority pass';
      if (facility.supportsSingleRider) yield 'シングルライダー single rider';
      if ((facility.thrillLevel ?? 0) >= 3) yield 'スリル thrill';
      yield* WishSearchMetadata.semanticTagsFor(facility.name);
      if (facility.isWaterRide) yield '水濡れ ウォーター water';
      if (facility.isDarkRide) yield 'ダークライド dark ride';
      if (facility.isSeasonal) yield '季節限定 期間限定 seasonal';
    }
  }


  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        eventPackRepository.loadBundledPacks(),
        facilityRepository.getFacilities(),
      ]);
      packs = results[0] as List<WishEventPack>;
      final facilities = results[1] as List<Facility>;
      _facilityById = <String, Facility>{
        for (final facility in facilities) facility.id: facility,
      };
      facilityWishItems = facilities
          .where(_isWishFacilityCategory)
          .map(_wishItemFromFacility)
          .toList(growable: false);
    } catch (error) {
      errorMessage = 'やりたいことデータを読み込めませんでした：$error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshRemote() async {
    isRefreshing = true;
    errorMessage = null;
    notifyListeners();
    try {
      packs = await eventPackRepository.refreshRemotePacks();
    } catch (error) {
      errorMessage = 'オンライン更新に失敗したため、内蔵データを使用します：$error';
      packs = await eventPackRepository.loadBundledPacks();
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  void setCategory(WishItemCategory? value) {
    categoryFilter = value;
    notifyListeners();
  }

  void setSelectedOnly(bool value) {
    selectedOnly = value;
    notifyListeners();
  }

  void setFreeDrinkOnly(bool value) {
    freeDrinkOnly = value;
    notifyListeners();
  }

  void selectItemsByCategories(
    Set<WishItemCategory> categories, {
    bool freeDrinkOnly = false,
  }) {
    final parkId = appState.tripSettings.parkId;
    final ids = allItems
        .where(
          (item) =>
              item.parkId == parkId &&
              categories.contains(item.category) &&
              (!freeDrinkOnly || item.freeDrinkEligible),
        )
        .map((item) => item.id);
    appState.selectWishItems(ids);
    notifyListeners();
  }

  void selectAllEligibleFreeDrinkMenus() {
    final parkId = appState.tripSettings.parkId;
    final ids = allItems
        .where(
          (item) =>
              item.parkId == parkId &&
              item.category.isFreeDrinkMenuCategory &&
              item.freeDrinkEligible,
        )
        .map((item) => item.id);
    appState.selectWishItems(ids);
    notifyListeners();
  }

  int get selectedCandidateOptionCount {
    return allItems
        .where((item) {
          final state = appState.wishStateFor(item.id);
          return state.selected && !state.completed;
        })
        .fold<int>(
          0,
          (total, item) =>
              total + (item.venueFacilityIds.isEmpty ? 1 : item.venueFacilityIds.length),
        );
  }

  int get selectedDistinctFacilityCandidateCount {
    return allItems
        .where((item) {
          final state = appState.wishStateFor(item.id);
          return state.selected && !state.completed;
        })
        .expand((item) => item.venueFacilityIds)
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;
  }

  Future<int> applySelectedItemsToPlan() async {
    final selected = allItems
        .where((item) {
          final state = appState.wishStateFor(item.id);
          return state.selected && !state.completed;
        })
        .toList(growable: false);

    final intents = const WishPlanningIntentResolver().resolve(
      items: selected,
      stateFor: appState.wishStateFor,
    );

    var added = 0;
    for (final intent in intents) {
      final facilityId = intent.facilityId;
      final facility = await facilityRepository.getFacilityById(facilityId);
      if (facility == null ||
          facility.parkId != appState.tripSettings.parkId ||
          !facility.canAddToPlanAt(effectiveDate)) {
        continue;
      }
      final targetCount = intent.targetCount;
      final existingCount = appState.selectedFacilities
          .where((value) => value.id == facilityId)
          .length;
      if (existingCount == 0) {
        appState.addFacility(facility);
        added++;
      }
      for (var occurrence = existingCount == 0 ? 1 : existingCount;
          occurrence < targetCount;
          occurrence++) {
        appState.addFacilityRepeat(facility);
        added++;
      }
      while (appState.selectedFacilities
              .where((value) => value.id == facilityId)
              .length > targetCount) {
        appState.removeOneFacilityOccurrence(facilityId);
      }
      appState.updatePreferencePriority(
        facilityId: facilityId,
        priority: intent.planPriority,
      );
      appState.updatePreferencePreferredTime(
        facilityId: facilityId,
        preferredTime: intent.preferredTime,
      );
      appState.updatePreferenceWaitTolerance(
        facilityId: facilityId,
        waitTolerance: intent.waitTolerance,
      );
    }

    return added;
  }

  bool supportsRepeatCount(WishItem item) => _supportsRepeatCount(item);

  bool _supportsRepeatCount(WishItem item) {
    return item.venueFacilityIds.length == 1 &&
        (item.category == WishItemCategory.attraction ||
            item.category == WishItemCategory.greeting);
  }

  bool _isSelectableOnEffectiveDate(WishItem item) {
    if (!item.isAvailableOn(effectiveDate)) {
      return false;
    }

    if (item.venueFacilityIds.isEmpty) {
      return true;
    }

    final knownVenues = item.venueFacilityIds
        .map((id) => _facilityById[id])
        .whereType<Facility>()
        .toList(growable: false);

    if (knownVenues.isEmpty) {
      return true;
    }

    return knownVenues.any(
      (facility) =>
          facility.parkId == item.parkId &&
          facility.canAddToPlanAt(effectiveDate),
    );
  }

  bool _isWishFacilityCategory(Facility facility) {
    return switch (facility.category) {
      FacilityCategory.attraction ||
      FacilityCategory.show ||
      FacilityCategory.parade ||
      FacilityCategory.greeting ||
      FacilityCategory.restaurant => true,
      _ => false,
    };
  }

  WishItem _wishItemFromFacility(Facility facility) {
    final category = switch (facility.category) {
      FacilityCategory.attraction => WishItemCategory.attraction,
      FacilityCategory.greeting => WishItemCategory.greeting,
      FacilityCategory.show ||
      FacilityCategory.parade => WishItemCategory.entertainment,
      FacilityCategory.restaurant =>
        facility.diningLocationType == DiningLocationType.disneyHotel
            ? WishItemCategory.hotelRestaurant
            : WishItemCategory.restaurant,
      _ => WishItemCategory.other,
    };

    return WishItem(
      id: 'facility:${facility.id}',
      name: facility.name,
      category: category,
      parkId: facility.parkId,
      venueFacilityIds: [facility.id],
      venueNames: [facility.name],
      startDate: DateTime(2000),
      endDate: DateTime(2100),
      eventPackId: 'facility_master',
      description: facility.description,
      officialUrl: facility.officialUrl,
      sourceCheckedAt: facility.operatingStatusCheckedAt,
    );
  }
}
