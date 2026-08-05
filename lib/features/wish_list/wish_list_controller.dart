import 'package:flutter/foundation.dart';

import '../../app/state/app_state.dart';
import '../../data/repositories/wish_event_pack_repository_impl.dart';
import '../../domain/entities/wish_event_pack.dart';
import '../../domain/entities/wish_item.dart';
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
  WishItemCategory? categoryFilter;
  bool freeDrinkOnly = false;
  String query = '';

  List<WishItem> get allItems {
    return packs.expand((pack) => pack.items).toList(growable: false);
  }

  List<WishItem> get visibleItems {
    final parkId = appState.tripSettings.parkId;
    return allItems
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
        .toList(growable: false)
      ..sort((left, right) {
        final leftState = appState.wishStateFor(left.id);
        final rightState = appState.wishStateFor(right.id);
        if (leftState.selected != rightState.selected) {
          return leftState.selected ? -1 : 1;
        }
        return rightState.priority.compareTo(leftState.priority);
      });
  }

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      packs = await eventPackRepository.loadBundledPacks();
    } catch (error) {
      errorMessage = 'イベントデータを読み込めませんでした：$error';
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
}
