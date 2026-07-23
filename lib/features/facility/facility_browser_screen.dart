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
import '../../domain/enums/facility_category.dart';
import 'facility_controller.dart';
import 'plan_builder_controller.dart';
import 'plan_preference_controller.dart';
import 'widgets/facility_card.dart';
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

  late final TextEditingController _searchController;

  bool _parkSynchronizationScheduled = false;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final appState = AppStateScope.of(context);

    if (_appState == null) {
      _initializeControllers(appState);
      return;
    }

    _appState = appState;
    _synchronizeParkFromSettings(appState);
  }

  void _initializeControllers(AppState appState) {
    _appState = appState;

    final facilityController = FacilityController(
      initialParkId: appState.tripSettings.parkId,
    );

    final planBuilderController = PlanBuilderController(appState);

    final planPreferenceController = PlanPreferenceController(appState);

    _facilityController = facilityController;
    _planBuilderController = planBuilderController;
    _planPreferenceController = planPreferenceController;

    facilityController.addListener(_refresh);
    planBuilderController.addListener(_refresh);
    planPreferenceController.addListener(_refresh);
  }

  void _synchronizeParkFromSettings(AppState appState) {
    final facilityController = _facilityController;

    if (facilityController == null) {
      return;
    }

    final settingsParkId = appState.tripSettings.parkId;

    if (settingsParkId.trim().isEmpty ||
        facilityController.selectedParkId == settingsParkId ||
        _parkSynchronizationScheduled) {
      return;
    }

    _parkSynchronizationScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _parkSynchronizationScheduled = false;

      if (!mounted) {
        return;
      }

      final latestParkId = _appState?.tripSettings.parkId;

      if (latestParkId == null ||
          latestParkId.trim().isEmpty ||
          facilityController.selectedParkId == latestParkId) {
        return;
      }

      facilityController.selectPark(latestParkId);
      _searchController.clear();
    });
  }

  @override
  void dispose() {
    _facilityController?.removeListener(_refresh);
    _planBuilderController?.removeListener(_refresh);
    _planPreferenceController?.removeListener(_refresh);

    _facilityController?.dispose();
    _planBuilderController?.dispose();
    _planPreferenceController?.dispose();

    _searchController.dispose();

    super.dispose();
  }

  void _refresh() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _addFacility(Facility facility) {
    _planBuilderController?.addFacility(facility);
  }

  void _removeFacility(String facilityId) {
    _planBuilderController?.removeFacility(facilityId);
  }

  void _clearFilters() {
    final facilityController = _facilityController;

    if (facilityController == null) {
      return;
    }

    facilityController.clearFilters();
    _searchController.clear();
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

    _synchronizeParkFromSettings(appState);

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
        padding: EdgeInsets.zero,
        children: [
          const SectionTitle(
            title: 'プラン編集',
            subtitle: '施設と希望条件を設定します。',
            icon: AppIcons.planEditorSelected,
          ),
          const SizedBox(height: AppSpacing.xs),
          _CompactCurrentPark(parkId: facilityController.selectedParkId),
          const SizedBox(height: AppSpacing.sm),
          _CompactSearchField(
            controller: _searchController,
            onChanged: facilityController.updateSearchKeyword,
          ),
          const SizedBox(height: AppSpacing.sm),
          _CompactCategoryFilter(
            selectedCategory: facilityController.selectedCategory,
            onSelected: facilityController.selectCategory,
          ),
          const SizedBox(height: AppSpacing.sm),
          _CompactAreaFilter(
            areaIds: facilityController.availableAreaIds,
            selectedAreaId: facilityController.selectedAreaId,
            areaLabel: facilityController.areaLabel,
            onSelected: facilityController.selectArea,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '表示件数：${filteredFacilities.length}件'
                  ' / 選択済み：${selectedFacilitiesForPark.length}件',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (facilityController.hasActiveFilters)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
                  label: const Text('条件解除'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _SelectedFacilityAccordion(
            facilities: selectedFacilitiesForPark,
            preferenceController: preferenceController,
            onRemove: _removeFacility,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('施設一覧', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          if (filteredFacilities.isEmpty)
            EmptyState(
              title: facilityController.selectedParkId == 'tokyo_disneysea'
                  ? '東京ディズニーシーの施設は準備中です'
                  : '施設が見つかりません',
              message: facilityController.selectedParkId == 'tokyo_disneysea'
                  ? '東京ディズニーシーの施設マスターデータは'
                        'まだ登録されていません。'
                  : '検索条件、カテゴリまたはエリアを'
                        '変更してください。',
            )
          else
            for (final facility in filteredFacilities)
              FacilityCard(
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

class _CompactCurrentPark extends StatelessWidget {
  const _CompactCurrentPark({required this.parkId});

  final String parkId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(_parkIcon, size: 19, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: '編集中：'),
                  TextSpan(
                    text: _parkName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: '（変更は設定から）',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String get _parkName {
    return switch (parkId) {
      'tokyo_disneyland' => '東京ディズニーランド',
      'tokyo_disneysea' => '東京ディズニーシー',
      _ => parkId,
    };
  }

  IconData get _parkIcon {
    return switch (parkId) {
      'tokyo_disneyland' => Icons.castle_outlined,
      'tokyo_disneysea' => Icons.water_outlined,
      _ => Icons.park_outlined,
    };
  }
}

class _CompactSearchField extends StatelessWidget {
  const _CompactSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: '施設名・カテゴリで検索',
          prefixIcon: const Icon(Icons.search, size: 21),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 42,
            minHeight: 42,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '検索文字を消去',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.close, size: 19),
                ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _CompactCategoryFilter extends StatelessWidget {
  const _CompactCategoryFilter({
    required this.selectedCategory,
    required this.onSelected,
  });

  final FacilityCategory? selectedCategory;
  final ValueChanged<FacilityCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <_CategoryFilterItem>[
      const _CategoryFilterItem(label: 'すべて'),
      _CategoryFilterItem(
        label: 'アトラクション',
        category: FacilityCategory.attraction,
      ),
      _CategoryFilterItem(label: 'ショー', category: FacilityCategory.show),
      _CategoryFilterItem(label: 'パレード', category: FacilityCategory.parade),
      _CategoryFilterItem(
        label: 'レストラン',
        category: FacilityCategory.restaurant,
      ),
      _CategoryFilterItem(label: 'ショップ', category: FacilityCategory.shop),
      _CategoryFilterItem(
        label: 'グリーティング',
        category: FacilityCategory.greeting,
      ),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) {
          return const SizedBox(width: 6);
        },
        itemBuilder: (context, index) {
          final item = items[index];

          final isSelected = item.category == selectedCategory;

          return ChoiceChip(
            selected: isSelected,
            showCheckmark: isSelected,
            label: Text(item.label, maxLines: 1, softWrap: false),
            labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
            visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            onSelected: (_) {
              onSelected(item.category);
            },
          );
        },
      ),
    );
  }
}

class _CategoryFilterItem {
  const _CategoryFilterItem({required this.label, this.category});

  final String label;
  final FacilityCategory? category;
}

class _CompactAreaFilter extends StatelessWidget {
  const _CompactAreaFilter({
    required this.areaIds,
    required this.selectedAreaId,
    required this.areaLabel,
    required this.onSelected,
  });

  final List<String> areaIds;
  final String? selectedAreaId;
  final String Function(String areaId) areaLabel;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 20),
            const SizedBox(width: 6),
            Text('エリアで絞り込み', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 6),

        // 1段目：すべてのエリア
        Align(
          alignment: Alignment.centerLeft,
          child: _AreaChoiceButton(
            label: 'すべてのエリア',
            selected: selectedAreaId == null,
            onPressed: () {
              onSelected(null);
            },
          ),
        ),

        // 2段目：各エリア
        if (areaIds.isNotEmpty) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: areaIds.length,
              separatorBuilder: (_, _) {
                return const SizedBox(width: 6);
              },
              itemBuilder: (context, index) {
                final areaId = areaIds[index];

                return _AreaChoiceButton(
                  label: areaLabel(areaId),
                  selected: selectedAreaId == areaId,
                  onPressed: () {
                    onSelected(areaId);
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _AreaChoiceButton extends StatelessWidget {
  const _AreaChoiceButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final backgroundColor = selected
        ? colorScheme.primaryContainer.withValues(alpha: 0.55)
        : colorScheme.surfaceContainerLowest;

    final borderColor = selected
        ? colorScheme.primary.withValues(alpha: 0.65)
        : colorScheme.outlineVariant;

    final foregroundColor = selected
        ? colorScheme.primary
        : colorScheme.onSurface;

    return Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 34,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(Icons.check, size: 15, color: foregroundColor),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: foregroundColor,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedFacilityAccordion extends StatelessWidget {
  const _SelectedFacilityAccordion({
    required this.facilities,
    required this.preferenceController,
    required this.onRemove,
  });

  final List<Facility> facilities;
  final PlanPreferenceController preferenceController;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final categoryGroups = _createCategoryGroups();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '選択済み施設',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text('${facilities.length}件'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (facilities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text('まだ施設が選択されていません。'),
            )
          else
            for (final group in categoryGroups)
              if (group.facilities.isNotEmpty)
                _CategoryAccordion(
                  group: group,
                  preferenceController: preferenceController,
                  onRemove: onRemove,
                ),
        ],
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

class _CategoryAccordion extends StatelessWidget {
  const _CategoryAccordion({
    required this.group,
    required this.preferenceController,
    required this.onRemove,
  });

  final _FacilityCategoryGroup group;
  final PlanPreferenceController preferenceController;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('category_${group.keyName}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(group.icon),
        title: Text(group.label),
        subtitle: Text('${group.facilities.length}件選択'),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          0,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        children: [
          if (group.keyName == 'shop')
            _ShopAccordionGroups(
              facilities: group.facilities,
              preferenceController: preferenceController,
              onRemove: onRemove,
            )
          else
            for (final facility in group.facilities)
              _FacilityAccordion(
                key: ValueKey('facility_${facility.id}'),
                facility: facility,
                preferenceController: preferenceController,
                onRemove: onRemove,
              ),
        ],
      ),
    );
  }
}

class _ShopAccordionGroups extends StatelessWidget {
  const _ShopAccordionGroups({
    required this.facilities,
    required this.preferenceController,
    required this.onRemove,
  });

  final List<Facility> facilities;
  final PlanPreferenceController preferenceController;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final generalShops = facilities
        .where((facility) => !facility.isCapsuleToy)
        .toList(growable: false);

    final capsuleToyShops = facilities
        .where((facility) => facility.isCapsuleToy)
        .toList(growable: false);

    return Column(
      children: [
        if (generalShops.isNotEmpty)
          _ShopGroupAccordion(
            key: const ValueKey('general_shop_group'),
            label: '一般ショップ',
            icon: Icons.storefront_outlined,
            facilities: generalShops,
            preferenceController: preferenceController,
            onRemove: onRemove,
          ),
        if (capsuleToyShops.isNotEmpty)
          _ShopGroupAccordion(
            key: const ValueKey('capsule_toy_group'),
            label: 'カプセルトイ',
            icon: Icons.catching_pokemon_outlined,
            facilities: capsuleToyShops,
            preferenceController: preferenceController,
            onRemove: onRemove,
          ),
      ],
    );
  }
}

class _ShopGroupAccordion extends StatelessWidget {
  const _ShopGroupAccordion({
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
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text('${facilities.length}件'),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          0,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        children: [
          for (final facility in facilities)
            _FacilityAccordion(
              key: ValueKey('shop_facility_${facility.id}'),
              facility: facility,
              preferenceController: preferenceController,
              onRemove: onRemove,
            ),
        ],
      ),
    );
  }
}

class _FacilityAccordion extends StatelessWidget {
  const _FacilityAccordion({
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

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                facility.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: '選択解除',
              onPressed: () {
                onRemove(facility.id);
              },
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        subtitle: Text(_buildFacilitySubtitle(facility)),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          0,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        children: [
          PlanPreferenceEditor(
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
        ],
      ),
    );
  }

  String _buildFacilitySubtitle(Facility facility) {
    if (facility.isShop) {
      return facility.shopType.label;
    }

    return switch (facility.category.name) {
      'attraction' => 'アトラクション',
      'restaurant' => 'レストラン',
      'show' => 'ショー',
      'parade' => 'パレード',
      'greeting' => 'グリーティング',
      _ => facility.category.name,
    };
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
