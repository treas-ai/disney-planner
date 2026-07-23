import 'package:flutter/material.dart';

import '../../app/state/app_state.dart';
import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/section_title.dart';
import '../../domain/entities/facility.dart';
import '../../domain/enums/restaurant_type.dart';
import '../../domain/enums/shop_type.dart';
import 'facility_controller.dart';
import 'plan_builder_controller.dart';
import 'plan_preference_controller.dart';
import 'widgets/facility_area_filter.dart';
import 'widgets/facility_card.dart';
import 'widgets/facility_category_filter.dart';
import 'widgets/facility_search_field.dart';
import 'widgets/plan_preference_editor.dart';

class FacilityBrowserScreen extends StatefulWidget {
  const FacilityBrowserScreen({super.key});

  @override
  State<FacilityBrowserScreen> createState() {
    return _FacilityBrowserScreenState();
  }
}

class _FacilityBrowserScreenState extends State<FacilityBrowserScreen> {
  AppState? _appState;

  FacilityController? _facilityController;
  PlanBuilderController? _planBuilderController;
  PlanPreferenceController? _planPreferenceController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_appState != null) {
      return;
    }

    final appState = AppStateScope.of(context);

    _appState = appState;

    _facilityController = FacilityController(
      initialParkId: appState.tripSettings.parkId,
    );

    _planBuilderController = PlanBuilderController(appState);

    _planPreferenceController = PlanPreferenceController(appState);

    _facilityController!.addListener(_refresh);

    _planBuilderController!.addListener(_refresh);

    _planPreferenceController!.addListener(_refresh);
  }

  @override
  void dispose() {
    _facilityController?.removeListener(_refresh);

    _planBuilderController?.removeListener(_refresh);

    _planPreferenceController?.removeListener(_refresh);

    _facilityController?.dispose();
    _planBuilderController?.dispose();
    _planPreferenceController?.dispose();

    super.dispose();
  }

  void _refresh() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _selectPark(String parkId) {
    final appState = _appState;
    final facilityController = _facilityController;

    if (appState == null || facilityController == null) {
      return;
    }

    facilityController.selectPark(parkId);

    appState.updateTripSettings(appState.tripSettings.copyWith(parkId: parkId));
  }

  void _addFacility(Facility facility) {
    _planBuilderController?.addFacility(facility);
  }

  void _removeFacility(String facilityId) {
    _planBuilderController?.removeFacility(facilityId);
  }

  @override
  Widget build(BuildContext context) {
    final appState = _appState;
    final facilityController = _facilityController;
    final planBuilderController = _planBuilderController;
    final preferenceController = _planPreferenceController;

    if (appState == null ||
        facilityController == null ||
        planBuilderController == null ||
        preferenceController == null) {
      return const AppScaffold(child: LoadingView(message: '施設画面を準備中です...'));
    }

    if (facilityController.isLoading) {
      return const AppScaffold(child: LoadingView(message: '施設データを読み込み中です...'));
    }

    if (facilityController.errorMessage != null) {
      return AppScaffold(
        child: EmptyState(
          title: '読み込みエラー',
          message: facilityController.errorMessage!,
          icon: Icons.error_outline,
        ),
      );
    }

    final filteredFacilities = facilityController.filteredFacilities;

    final selectedFacilitiesForPark = planBuilderController.selectedFacilities
        .where(
          (facility) => facility.parkId == facilityController.selectedParkId,
        )
        .toList(growable: false);

    return AppScaffold(
      child: ListView(
        children: [
          const SectionTitle(
            title: 'プラン編集',
            subtitle: 'パークを選び、施設と希望条件を設定します。',
            icon: AppIcons.planEditorSelected,
          ),
          _ParkSelectorCard(
            selectedParkId: facilityController.selectedParkId,
            onChanged: _selectPark,
          ),
          FacilitySearchField(
            onChanged: facilityController.updateSearchKeyword,
          ),
          FacilityCategoryFilter(
            selectedCategory: facilityController.selectedCategory,
            onSelected: facilityController.selectCategory,
          ),
          FacilityAreaFilter(
            areaIds: facilityController.availableAreaIds,
            selectedAreaId: facilityController.selectedAreaId,
            areaLabelBuilder: facilityController.areaLabel,
            onSelected: facilityController.selectArea,
          ),
          _FilterResultSummary(
            displayedCount: filteredFacilities.length,
            selectedCount: selectedFacilitiesForPark.length,
            selectedAreaLabel: facilityController.selectedAreaId == null
                ? null
                : facilityController.areaLabel(
                    facilityController.selectedAreaId!,
                  ),
            onClearFilters: facilityController.clearFilters,
            hasActiveFilter:
                facilityController.selectedCategory != null ||
                facilityController.selectedAreaId != null ||
                facilityController.searchKeyword.trim().isNotEmpty,
          ),
          _SelectedFacilityPanel(
            facilities: selectedFacilitiesForPark,
            preferenceController: preferenceController,
            onRemove: _removeFacility,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  '施設一覧',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (facilityController.selectedAreaId != null)
                Chip(
                  avatar: const Icon(Icons.location_on_outlined, size: 18),
                  label: Text(
                    facilityController.areaLabel(
                      facilityController.selectedAreaId!,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (filteredFacilities.isEmpty)
            EmptyState(
              title: '施設が見つかりません',
              message: facilityController.selectedAreaId != null
                  ? '選択中のエリアには、条件に一致する施設がありません。'
                  : '検索条件またはカテゴリを変更してください。',
            )
          else
            for (final facility in filteredFacilities)
              FacilityCard(
                key: ValueKey('facility_card_${facility.id}'),
                facility: facility,
                isSelected: planBuilderController.isSelected(facility.id),
                onAdd: () {
                  _addFacility(facility);
                },
                onRemove: () {
                  _removeFacility(facility.id);
                },
              ),
        ],
      ),
    );
  }
}

class _FilterResultSummary extends StatelessWidget {
  const _FilterResultSummary({
    required this.displayedCount,
    required this.selectedCount,
    required this.selectedAreaLabel,
    required this.onClearFilters,
    required this.hasActiveFilter,
  });

  final int displayedCount;
  final int selectedCount;
  final String? selectedAreaLabel;
  final VoidCallback onClearFilters;
  final bool hasActiveFilter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '表示件数：'
              '$displayedCount件'
              ' / このパークの選択済み：'
              '$selectedCount件'
              '${selectedAreaLabel == null ? '' : ' / エリア：$selectedAreaLabel'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (hasActiveFilter)
            TextButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off, size: 18),
              label: const Text('条件解除'),
            ),
        ],
      ),
    );
  }
}

class _SelectedFacilityPanel extends StatelessWidget {
  const _SelectedFacilityPanel({
    required this.facilities,
    required this.preferenceController,
    required this.onRemove,
  });

  final List<Facility> facilities;
  final PlanPreferenceController preferenceController;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final categoryGroups = _createCategoryGroups();

    return Material(
      color: colorScheme.primaryContainer.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '選択済み施設',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${facilities.length}件',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: AppSpacing.sm),
            if (facilities.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  'まだ施設が選択されていません。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final group in categoryGroups)
                if (group.facilities.isNotEmpty)
                  _CategorySection(
                    key: ValueKey(
                      'selected_category_'
                      '${group.keyName}',
                    ),
                    group: group,
                    preferenceController: preferenceController,
                    onRemove: onRemove,
                  ),
          ],
        ),
      ),
    );
  }

  List<_FacilityCategoryGroup> _createCategoryGroups() {
    return [
      _FacilityCategoryGroup(
        keyName: 'attraction',
        label: 'アトラクション',
        icon: Icons.attractions_outlined,
        facilities: _whereCategory('attraction'),
      ),
      _FacilityCategoryGroup(
        keyName: 'restaurant',
        label: 'レストラン',
        icon: Icons.restaurant_outlined,
        facilities: _whereCategory('restaurant'),
      ),
      _FacilityCategoryGroup(
        keyName: 'show_parade',
        label: 'ショー・パレード',
        icon: Icons.theater_comedy_outlined,
        facilities: facilities
            .where(
              (facility) =>
                  facility.category.name == 'show' ||
                  facility.category.name == 'parade',
            )
            .toList(growable: false),
      ),
      _FacilityCategoryGroup(
        keyName: 'greeting',
        label: 'グリーティング',
        icon: Icons.photo_camera_front_outlined,
        facilities: _whereCategory('greeting'),
      ),
      _FacilityCategoryGroup(
        keyName: 'shop',
        label: 'ショップ',
        icon: Icons.shopping_bag_outlined,
        facilities: _whereCategory('shop'),
      ),
    ];
  }

  List<Facility> _whereCategory(String categoryName) {
    return facilities
        .where((facility) => facility.category.name == categoryName)
        .toList(growable: false);
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    super.key,
    required this.group,
    required this.preferenceController,
    required this.onRemove,
  });

  final _FacilityCategoryGroup group;
  final PlanPreferenceController preferenceController;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: colorScheme.primaryContainer.withValues(alpha: 0.42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: ValueKey(
            'category_tile_'
            '${group.keyName}',
          ),
          initiallyExpanded: group.facilities.length <= 4,
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            0,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          leading: Icon(group.icon, size: 20, color: colorScheme.primary),
          title: Text(
            group.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '${group.facilities.length}件選択',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            if (group.keyName == 'restaurant')
              _RestaurantGroupedList(
                facilities: group.facilities,
                preferenceController: preferenceController,
                onRemove: onRemove,
              )
            else if (group.keyName == 'shop')
              _ShopGroupedList(
                facilities: group.facilities,
                preferenceController: preferenceController,
                onRemove: onRemove,
              )
            else
              for (final facility in group.facilities)
                _SelectedFacilityItem(
                  key: ValueKey(
                    'selected_'
                    '${facility.id}',
                  ),
                  facility: facility,
                  preferenceController: preferenceController,
                  onRemove: onRemove,
                ),
          ],
        ),
      ),
    );
  }
}

class _RestaurantGroupedList extends StatelessWidget {
  const _RestaurantGroupedList({
    required this.facilities,
    required this.preferenceController,
    required this.onRemove,
  });

  final List<Facility> facilities;
  final PlanPreferenceController preferenceController;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final groups = <_RestaurantGroupData>[
      const _RestaurantGroupData(
        type: RestaurantType.tableService,
        icon: Icons.table_restaurant_outlined,
      ),
      const _RestaurantGroupData(
        type: RestaurantType.counterService,
        icon: Icons.countertops_outlined,
      ),
      const _RestaurantGroupData(
        type: RestaurantType.buffet,
        icon: Icons.dinner_dining_outlined,
      ),
      const _RestaurantGroupData(
        type: RestaurantType.bakeryCafe,
        icon: Icons.local_cafe_outlined,
      ),
      const _RestaurantGroupData(
        type: RestaurantType.snackStand,
        icon: Icons.icecream_outlined,
      ),
      const _RestaurantGroupData(
        type: RestaurantType.foodWagon,
        icon: Icons.local_shipping_outlined,
      ),
    ];

    final widgets = <Widget>[];

    for (final group in groups) {
      final matchingFacilities = facilities
          .where((facility) => facility.restaurantType == group.type)
          .toList(growable: false);

      if (matchingFacilities.isEmpty) {
        continue;
      }

      widgets.add(
        _FacilityTypeGroup(
          key: ValueKey(
            'restaurant_type_'
            '${group.type.name}',
          ),
          label: group.type.label,
          icon: group.icon,
          facilities: matchingFacilities,
          preferenceController: preferenceController,
          onRemove: onRemove,
        ),
      );
    }

    final unclassified = facilities
        .where((facility) => facility.restaurantType == RestaurantType.none)
        .toList(growable: false);

    if (unclassified.isNotEmpty) {
      widgets.add(
        _FacilityTypeGroup(
          key: const ValueKey('restaurant_type_none'),
          label: '種別未設定',
          icon: Icons.help_outline,
          facilities: unclassified,
          preferenceController: preferenceController,
          onRemove: onRemove,
        ),
      );
    }

    return Column(children: widgets);
  }
}

class _ShopGroupedList extends StatelessWidget {
  const _ShopGroupedList({
    required this.facilities,
    required this.preferenceController,
    required this.onRemove,
  });

  final List<Facility> facilities;
  final PlanPreferenceController preferenceController;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final groups = <_ShopGroupData>[
      const _ShopGroupData(
        type: ShopType.general,
        icon: Icons.storefront_outlined,
      ),
      const _ShopGroupData(
        type: ShopType.capsuleToy,
        icon: Icons.catching_pokemon_outlined,
      ),
      const _ShopGroupData(
        type: ShopType.apparel,
        icon: Icons.checkroom_outlined,
      ),
      const _ShopGroupData(
        type: ShopType.confectionery,
        icon: Icons.cake_outlined,
      ),
      const _ShopGroupData(
        type: ShopType.souvenir,
        icon: Icons.card_giftcard_outlined,
      ),
      const _ShopGroupData(type: ShopType.specialty, icon: Icons.star_outline),
      const _ShopGroupData(
        type: ShopType.photoService,
        icon: Icons.photo_camera_outlined,
      ),
      const _ShopGroupData(
        type: ShopType.limited,
        icon: Icons.event_available_outlined,
      ),
    ];

    final widgets = <Widget>[];

    for (final group in groups) {
      final matchingFacilities = facilities
          .where((facility) => facility.shopType == group.type)
          .toList(growable: false);

      if (matchingFacilities.isEmpty) {
        continue;
      }

      widgets.add(
        _FacilityTypeGroup(
          key: ValueKey(
            'shop_type_'
            '${group.type.name}',
          ),
          label: group.type.label,
          icon: group.icon,
          facilities: matchingFacilities,
          preferenceController: preferenceController,
          onRemove: onRemove,
        ),
      );
    }

    final unclassified = facilities
        .where((facility) => facility.shopType == ShopType.none)
        .toList(growable: false);

    if (unclassified.isNotEmpty) {
      widgets.add(
        _FacilityTypeGroup(
          key: const ValueKey('shop_type_none'),
          label: '種別未設定',
          icon: Icons.help_outline,
          facilities: unclassified,
          preferenceController: preferenceController,
          onRemove: onRemove,
        ),
      );
    }

    return Column(children: widgets);
  }
}

class _FacilityTypeGroup extends StatelessWidget {
  const _FacilityTypeGroup({
    super.key,
    required this.label,
    required this.icon,
    required this.facilities,
    required this.preferenceController,
    required this.onRemove,
  });

  final String label;
  final IconData icon;
  final List<Facility> facilities;
  final PlanPreferenceController preferenceController;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '${facilities.length}件',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            for (final facility in facilities)
              _SelectedFacilityItem(
                key: ValueKey(
                  'grouped_'
                  '${facility.id}',
                ),
                facility: facility,
                preferenceController: preferenceController,
                onRemove: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedFacilityItem extends StatelessWidget {
  const _SelectedFacilityItem({
    super.key,
    required this.facility,
    required this.preferenceController,
    required this.onRemove,
  });

  final Facility facility;
  final PlanPreferenceController preferenceController;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final preference = preferenceController.getPreference(facility.id);

    if (preference == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Material(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: ValueKey(
            'facility_tile_'
            '${facility.id}',
          ),
          tilePadding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.xs,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            0,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          leading: Icon(
            _facilityIcon(facility),
            size: 19,
            color: colorScheme.primary,
          ),
          title: Text(
            facility.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            _facilitySummary(facility),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: IconButton(
            tooltip: '選択解除',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              onRemove(facility.id);
            },
            icon: const Icon(Icons.close, size: 19),
          ),
          children: [
            Material(
              color: colorScheme.secondaryContainer.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: PlanPreferenceEditor(
                  facility: facility,
                  preference: preference,
                  onPriorityChanged: (priority) {
                    preferenceController.updatePriority(
                      facilityId: facility.id,
                      priority: priority,
                    );
                  },
                  onPreferredTimeChanged: (preferredTime) {
                    preferenceController.updatePreferredTime(
                      facilityId: facility.id,
                      preferredTime: preferredTime,
                    );
                  },
                  onWaitToleranceChanged: (waitTolerance) {
                    preferenceController.updateWaitTolerance(
                      facilityId: facility.id,
                      waitTolerance: waitTolerance,
                    );
                  },
                  onMealPreferenceChanged: (mealPreference) {
                    preferenceController.updateMealPreference(
                      facilityId: facility.id,
                      mealPreference: mealPreference,
                    );
                  },
                  onUseDpaChanged: (value) {
                    preferenceController.updateUseDpa(
                      facilityId: facility.id,
                      value: value,
                    );
                  },
                  onUsePriorityPassChanged: (value) {
                    preferenceController.updateUsePriorityPass(
                      facilityId: facility.id,
                      value: value,
                    );
                  },
                  onUseStandbyPassChanged: (value) {
                    preferenceController.updateUseStandbyPass(
                      facilityId: facility.id,
                      value: value,
                    );
                  },
                  onPrioritizeCapsuleToyChanged: (value) {
                    preferenceController.updatePrioritizeCapsuleToy(
                      facilityId: facility.id,
                      value: value,
                    );
                  },
                  onMemoChanged: (memo) {
                    preferenceController.updateMemo(
                      facilityId: facility.id,
                      memo: memo,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _facilityIcon(Facility facility) {
    if (facility.isShowRestaurant) {
      return Icons.theater_comedy_outlined;
    }

    if (facility.isPopcornWagon) {
      return Icons.local_movies_outlined;
    }

    if (facility.isRestaurant) {
      return Icons.restaurant_outlined;
    }

    if (facility.isShop) {
      return Icons.shopping_bag_outlined;
    }

    return switch (facility.category.name) {
      'attraction' => Icons.attractions_outlined,
      'show' => Icons.theater_comedy_outlined,
      'parade' => Icons.celebration_outlined,
      'greeting' => Icons.photo_camera_front_outlined,
      _ => Icons.place_outlined,
    };
  }

  String _facilitySummary(Facility facility) {
    final labels = <String>[];

    if (facility.isShowRestaurant) {
      labels.add(facility.showName ?? 'ショーレストラン');
    } else if (facility.isRestaurant &&
        facility.restaurantType != RestaurantType.none) {
      labels.add(facility.restaurantType.label);
    } else if (facility.isShop && facility.shopType != ShopType.none) {
      labels.add(facility.shopType.label);
    } else {
      labels.add(facility.category.label);
    }

    final primaryProduct = facility.primaryProductLabel;

    if (primaryProduct != null) {
      labels.add(primaryProduct);
    }

    return labels.join('・');
  }
}

class _FacilityCategoryGroup {
  const _FacilityCategoryGroup({
    required this.keyName,
    required this.label,
    required this.icon,
    required this.facilities,
  });

  final String keyName;
  final String label;
  final IconData icon;
  final List<Facility> facilities;
}

class _RestaurantGroupData {
  const _RestaurantGroupData({required this.type, required this.icon});

  final RestaurantType type;
  final IconData icon;
}

class _ShopGroupData {
  const _ShopGroupData({required this.type, required this.icon});

  final ShopType type;
  final IconData icon;
}

class _ParkSelectorCard extends StatelessWidget {
  const _ParkSelectorCard({
    required this.selectedParkId,
    required this.onChanged,
  });

  final String selectedParkId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: DropdownButtonFormField<String>(
        key: ValueKey(selectedParkId),
        initialValue: selectedParkId,
        decoration: const InputDecoration(
          labelText: '編集するパーク',
          helperText: 'パークを切り替えても、別パークの選択内容は残ります。',
          prefixIcon: Icon(Icons.park_outlined),
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(
            value: 'tokyo_disneyland',
            child: Text('東京ディズニーランド'),
          ),
          DropdownMenuItem(value: 'tokyo_disneysea', child: Text('東京ディズニーシー')),
        ],
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }
}
