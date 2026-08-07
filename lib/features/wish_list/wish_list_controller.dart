import 'package:flutter/foundation.dart';

import '../../app/state/app_state.dart';
import '../../data/repositories/wish_event_pack_repository_impl.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/wish_event_pack.dart';
import '../../domain/entities/wish_item.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/enums/dining_location_type.dart';
import '../../domain/enums/priority_level.dart';
import '../../domain/enums/wish_item_category.dart';
import '../../domain/repositories/facility_repository.dart';
import '../../domain/repositories/wish_event_pack_repository.dart';

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
  WishItemCategory? categoryFilter;
  bool freeDrinkOnly = false;
  String query = '';

  DateTime get effectiveDate => DateTime.now();

  List<WishItem> get allLoadedItems {
    final byId = <String, WishItem>{};
    for (final item in packs.expand((pack) => pack.items)) {
      byId[item.id] = item;
    }
    for (final item in facilityWishItems) {
      byId.putIfAbsent(item.id, () => item);
    }
    return List<WishItem>.unmodifiable(byId.values);
  }

  List<WishItem> get allItems {
    return allLoadedItems
        .where((item) => item.isAvailableOn(effectiveDate))
        .toList(growable: false);
  }

  List<WishItem> get visibleItems {
    final parkId = appState.tripSettings.parkId;
    final items = allItems
        .where((item) {
          if (item.parkId != parkId) {
            return false;
          }
          if (categoryFilter != null && item.category != categoryFilter) {
            return false;
          }
          if (freeDrinkOnly && !item.freeDrinkEligible) {
            return false;
          }
          final normalized = query.trim().toLowerCase();
          if (normalized.isNotEmpty) {
            final target =
                '${item.name} ${item.venueNames.join(' ')} '
                        '${item.description ?? ''}'
                    .toLowerCase();
            if (!target.contains(normalized)) {
              return false;
            }
          }
          return true;
        })
        .toList(growable: false);

    items.sort((left, right) {
      final leftState = appState.wishStateFor(left.id);
      final rightState = appState.wishStateFor(right.id);
      final priorityCompare = rightState.priority.compareTo(leftState.priority);
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      return left.name.compareTo(right.name);
    });
    return items;
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
      facilityWishItems = facilities
          .where(_isWishFacility)
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

    final facilityIds = selected
        .expand((item) => item.venueFacilityIds)
        .where((id) => id.isNotEmpty)
        .toSet();

    var added = 0;
    for (final facilityId in facilityIds) {
      final facility = await facilityRepository.getFacilityById(facilityId);
      if (facility == null || facility.parkId != appState.tripSettings.parkId) {
        continue;
      }
      if (!appState.isFacilitySelected(facilityId)) {
        appState.addFacility(facility);
        added++;
      }
      appState.updatePreferencePriority(
        facilityId: facilityId,
        priority: PriorityLevel.high,
      );
    }

    return added;
  }

  bool _isWishFacility(Facility facility) {
    if (!facility.canAddToPlanAt(effectiveDate)) {
      return false;
    }
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
