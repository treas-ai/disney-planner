import 'package:flutter/material.dart';

import '../../app/state/app_state.dart';
import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../domain/entities/facility.dart';
import 'facility_controller.dart';
import 'facility_operating_filter.dart';
import 'plan_builder_controller.dart';
import 'plan_preference_controller.dart';
import 'widgets/facility_area_filter.dart';
import 'widgets/facility_card.dart';
import 'widgets/facility_category_filter.dart';
import 'widgets/facility_operating_status_filter.dart';
import 'widgets/facility_sort_selector.dart';
import 'widgets/selected_facility_editor_sheet.dart';

class FacilityBrowserScreen extends StatefulWidget {
  const FacilityBrowserScreen({
    super.key,
    required this.searchController,
    required this.onReviewPlanPressed,
  });

  final TextEditingController searchController;
  final VoidCallback onReviewPlanPressed;

  @override
  State<FacilityBrowserScreen> createState() {
    return _FacilityBrowserScreenState();
  }
}

class _FacilityBrowserScreenState
    extends State<FacilityBrowserScreen> {
  AppState? _appState;
  FacilityController? _facilityController;
  PlanBuilderController? _planBuilderController;
  PlanPreferenceController? _planPreferenceController;

  late final ScrollController _scrollController;

  bool _parkSynchronizationScheduled = false;
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();

    widget.searchController.addListener(
      _handleSearchChanged,
    );
  }

  @override
  void didUpdateWidget(
    FacilityBrowserScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (identical(
      oldWidget.searchController,
      widget.searchController,
    )) {
      return;
    }

    oldWidget.searchController.removeListener(
      _handleSearchChanged,
    );

    widget.searchController.addListener(
      _handleSearchChanged,
    );

    _handleSearchChanged();
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

  void _initializeControllers(
    AppState appState,
  ) {
    _appState = appState;

    final facilityController = FacilityController(
      initialParkId: appState.tripSettings.parkId,
    );

    final planBuilderController =
        PlanBuilderController(appState);

    final planPreferenceController =
        PlanPreferenceController(appState);

    _facilityController = facilityController;
    _planBuilderController = planBuilderController;
    _planPreferenceController =
        planPreferenceController;

    facilityController.addListener(_refresh);
    planBuilderController.addListener(_refresh);
    planPreferenceController.addListener(_refresh);

    facilityController.updateSearchKeyword(
      widget.searchController.text,
    );
  }

  void _handleSearchChanged() {
    _facilityController?.updateSearchKeyword(
      widget.searchController.text,
    );
  }

  void _synchronizeParkFromSettings(
    AppState appState,
  ) {
    final controller = _facilityController;

    if (controller == null) {
      return;
    }

    final settingsParkId =
        appState.tripSettings.parkId;

    if (settingsParkId.trim().isEmpty ||
        controller.selectedParkId == settingsParkId ||
        _parkSynchronizationScheduled) {
      return;
    }

    _parkSynchronizationScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        _parkSynchronizationScheduled = false;

        if (!mounted) {
          return;
        }

        final latestParkId =
            _appState?.tripSettings.parkId;

        if (latestParkId == null ||
            latestParkId.trim().isEmpty ||
            controller.selectedParkId ==
                latestParkId) {
          return;
        }

        controller.selectPark(latestParkId);

        widget.searchController.clear();
      },
    );
  }

  @override
  void dispose() {
    widget.searchController.removeListener(
      _handleSearchChanged,
    );

    _facilityController?.removeListener(_refresh);
    _planBuilderController?.removeListener(_refresh);
    _planPreferenceController?.removeListener(_refresh);

    _facilityController?.dispose();
    _planBuilderController?.dispose();
    _planPreferenceController?.dispose();

    _scrollController.dispose();

    super.dispose();
  }

  void _refresh() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _addFacility(
    Facility facility,
  ) {
    _planBuilderController?.addFacility(
      facility,
    );
  }

  void _removeFacility(
    String facilityId,
  ) {
    _planBuilderController?.removeFacility(
      facilityId,
    );
  }

  void _clearFilters() {
    final controller = _facilityController;

    if (controller == null) {
      return;
    }

    controller.clearFilters();

    widget.searchController.clear();
  }

  void _clearFiltersAndSort() {
    final controller = _facilityController;

    if (controller == null) {
      return;
    }

    controller.resetFiltersAndSort();

    widget.searchController.clear();
  }

  void _changePark(
    String parkId,
  ) {
    final appState = _appState;
    final controller = _facilityController;

    if (appState == null ||
        controller == null ||
        parkId.trim().isEmpty ||
        controller.selectedParkId == parkId) {
      return;
    }

    appState.updateTripSettings(
      appState.tripSettings.copyWith(
        parkId: parkId,
      ),
    );

    controller.selectPark(parkId);

    widget.searchController.clear();

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(
          milliseconds: 220,
        ),
        curve: Curves.easeOut,
      );
    }
  }

  void _openSelectedFacilityEditor() {
    final planBuilderController =
        _planBuilderController;

    final preferenceController =
        _planPreferenceController;

    final facilityController =
        _facilityController;

    if (planBuilderController == null ||
        preferenceController == null ||
        facilityController == null) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SelectedFacilityEditorSheet(
          planBuilderController:
              planBuilderController,
          preferenceController:
              preferenceController,
          selectedParkId:
              facilityController.selectedParkId,
          onReviewPlanPressed:
              widget.onReviewPlanPressed,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = _appState;
    final facilityController =
        _facilityController;
    final planBuilderController =
        _planBuilderController;

    if (appState == null ||
        facilityController == null ||
        planBuilderController == null ||
        _planPreferenceController == null) {
      return const AppScaffold(
        includeBottomSafeArea: false,
        child: LoadingView(
          message: '施設画面を準備中です...',
        ),
      );
    }

    _synchronizeParkFromSettings(appState);

    if (facilityController.isLoading) {
      return const AppScaffold(
        includeBottomSafeArea: false,
        child: LoadingView(
          message: '施設データを読み込み中です...',
        ),
      );
    }

    if (facilityController.errorMessage != null) {
      return AppScaffold(
        includeBottomSafeArea: false,
        child: EmptyState(
          title: '読み込みエラー',
          message:
              facilityController.errorMessage!,
          icon: Icons.error_outline,
        ),
      );
    }

    final facilities =
        facilityController.visibleFacilities(
      isSelected:
          planBuilderController.isSelected,
    );

    final selectedCount =
        planBuilderController
            .selectedFacilityCountForPark(
      facilityController.selectedParkId,
    );

    return AppScaffold(
      includeBottomSafeArea: false,
      child: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          final compact =
              constraints.maxWidth < 600;

          return Column(
            children: [
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  interactive: true,
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.only(
                      right: compact ? 8 : 14,
                      bottom: AppSpacing.md,
                    ),
                    children: [
                      _EditorParkHeader(
                        selectedParkId:
                            facilityController
                                .selectedParkId,
                        onParkChanged:
                            _changePark,
                      ),
                      const SizedBox(
                        height: AppSpacing.sm,
                      ),
                      if (compact)
                        _CompactFilterPanel(
                          expanded:
                              _filtersExpanded,
                          facilityController:
                              facilityController,
                          onToggle: () {
                            setState(() {
                              _filtersExpanded =
                                  !_filtersExpanded;
                            });
                          },
                          onClearFilters:
                              _clearFilters,
                          onResetAll:
                              _clearFiltersAndSort,
                        )
                      else
                        _FilterSection(
                          facilityController:
                              facilityController,
                          onClearFilters:
                              _clearFilters,
                          onResetAll:
                              _clearFiltersAndSort,
                        ),
                      const SizedBox(
                        height: AppSpacing.sm,
                      ),
                      _FacilityCountRow(
                        displayedCount:
                            facilities.length,
                        selectedCount:
                            selectedCount,
                        totalCount:
                            facilityController
                                .parkFacilities
                                .length,
                        sortLabel:
                            facilityController
                                .selectedSortType
                                .label,
                      ),
                      const SizedBox(
                        height: AppSpacing.sm,
                      ),
                      Text(
                        '施設一覧',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.w700,
                            ),
                      ),
                      const SizedBox(
                        height: AppSpacing.sm,
                      ),
                      if (facilities.isEmpty)
                        EmptyState(
                          title:
                              '施設が見つかりません',
                          message: widget
                                  .searchController
                                  .text
                                  .trim()
                                  .isNotEmpty
                              ? '「${widget.searchController.text}」に一致する施設がありません。'
                              : '検索条件、カテゴリ、エリアまたは営業状態を変更してください。',
                          icon:
                              Icons.search_off_outlined,
                        )
                      else
                        for (final facility
                            in facilities) ...[
                          FacilityCard(
                            facility: facility,
                            isSelected:
                                planBuilderController
                                    .isSelected(
                              facility.id,
                            ),
                            onAdd: () {
                              _addFacility(facility);
                            },
                            onRemove: () {
                              _removeFacility(
                                facility.id,
                              );
                            },
                          ),
                          const SizedBox(
                            height: AppSpacing.sm,
                          ),
                        ],
                    ],
                  ),
                ),
              ),
              const SizedBox(
                height: AppSpacing.xs,
              ),
              _SelectedFacilityBottomBar(
                selectedCount: selectedCount,
                onPressed:
                    _openSelectedFacilityEditor,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SelectedFacilityBottomBar
    extends StatelessWidget {
  const _SelectedFacilityBottomBar({
    required this.selectedCount,
    required this.onPressed,
  });

  final int selectedCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      elevation: 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          0,
          8,
          0,
          8,
        ),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Material(
          color: selectedCount > 0
              ? colorScheme.primary
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(
            12,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              height: 50,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: selectedCount > 0
                            ? colorScheme.onPrimary
                                .withValues(alpha: 0.16)
                            : colorScheme
                                .surfaceContainerHighest,
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons
                            .playlist_add_check_outlined,
                        size: 20,
                        color: selectedCount > 0
                            ? colorScheme.onPrimary
                            : colorScheme
                                .onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(
                      width: 11,
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedCount > 0
                                ? '選択施設 $selectedCount件'
                                : '選択施設はありません',
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: selectedCount >
                                          0
                                      ? colorScheme
                                          .onPrimary
                                      : colorScheme
                                          .onSurfaceVariant,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                          ),
                          Text(
                            selectedCount > 0
                                ? '内容・順番・希望条件を確認'
                                : '施設一覧から追加してください',
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: selectedCount >
                                          0
                                      ? colorScheme
                                          .onPrimary
                                          .withValues(
                                            alpha: 0.86,
                                          )
                                      : colorScheme
                                          .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Icon(
                      Icons.keyboard_arrow_up,
                      color: selectedCount > 0
                          ? colorScheme.onPrimary
                          : colorScheme
                              .onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorParkHeader extends StatelessWidget {
  const _EditorParkHeader({
    required this.selectedParkId,
    required this.onParkChanged,
  });

  final String selectedParkId;
  final ValueChanged<String> onParkChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _parkIcon(selectedParkId),
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(
                width: 7,
              ),
              Expanded(
                child: Text(
                  '編集中：${_parkName(selectedParkId)}',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        fontWeight:
                            FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 9,
          ),
          Row(
            children: [
              Expanded(
                child: _ParkSwitchButton(
                  label: 'ランド',
                  icon:
                      Icons.castle_outlined,
                  selected:
                      selectedParkId ==
                      'tokyo_disneyland',
                  onPressed: () {
                    onParkChanged(
                      'tokyo_disneyland',
                    );
                  },
                ),
              ),
              const SizedBox(
                width: 6,
              ),
              Expanded(
                child: _ParkSwitchButton(
                  label: 'シー',
                  icon:
                      Icons.water_outlined,
                  selected:
                      selectedParkId ==
                      'tokyo_disneysea',
                  onPressed: () {
                    onParkChanged(
                      'tokyo_disneysea',
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactFilterPanel extends StatelessWidget {
  const _CompactFilterPanel({
    required this.expanded,
    required this.facilityController,
    required this.onToggle,
    required this.onClearFilters,
    required this.onResetAll,
  });

  final bool expanded;
  final FacilityController facilityController;
  final VoidCallback onToggle;
  final VoidCallback onClearFilters;
  final VoidCallback onResetAll;

  @override
  Widget build(BuildContext context) {
    final activeCount =
        _activeConditionCount(
      facilityController,
    );

    return AppCard(
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius:
                BorderRadius.circular(10),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                vertical: 3,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.tune_outlined,
                    size: 21,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child: Text(
                      '絞り込み・並び替え',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight.w700,
                          ),
                    ),
                  ),
                  if (activeCount > 0)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$activeCount件適用中',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                      ),
                    ),
                  const SizedBox(
                    width: 5,
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(
                      milliseconds: 180,
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(
              milliseconds: 180,
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(
              width: double.infinity,
            ),
            secondChild: Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.md,
              ),
              child: _FilterContents(
                facilityController:
                    facilityController,
                onClearFilters:
                    onClearFilters,
                onResetAll: onResetAll,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _activeConditionCount(
    FacilityController controller,
  ) {
    var count = 0;

    if (controller.selectedCategory != null) {
      count++;
    }

    if (controller.selectedAreaId != null) {
      count++;
    }

    if (controller.selectedOperatingFilter !=
        FacilityOperatingFilter.all) {
      count++;
    }

    if (!controller.isDefaultSort) {
      count++;
    }

    return count;
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.facilityController,
    required this.onClearFilters,
    required this.onResetAll,
  });

  final FacilityController facilityController;
  final VoidCallback onClearFilters;
  final VoidCallback onResetAll;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: _FilterContents(
        facilityController:
            facilityController,
        onClearFilters:
            onClearFilters,
        onResetAll:
            onResetAll,
      ),
    );
  }
}

class _FilterContents extends StatelessWidget {
  const _FilterContents({
    required this.facilityController,
    required this.onClearFilters,
    required this.onResetAll,
  });

  final FacilityController facilityController;
  final VoidCallback onClearFilters;
  final VoidCallback onResetAll;

  @override
  Widget build(BuildContext context) {
    final hasChangedConditions =
        facilityController.hasActiveFilters ||
        !facilityController.isDefaultSort;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.category_outlined,
              size: 21,
            ),
            const SizedBox(
              width: AppSpacing.sm,
            ),
            Text(
              'カテゴリで絞り込み',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),
          ],
        ),
        const SizedBox(
          height: AppSpacing.sm,
        ),
        FacilityCategoryFilter(
          selectedCategory:
              facilityController.selectedCategory,
          onSelected:
              facilityController.selectCategory,
        ),
        FacilityAreaFilter(
          areaIds:
              facilityController.availableAreaIds,
          selectedAreaId:
              facilityController.selectedAreaId,
          areaLabelBuilder:
              facilityController.areaLabel,
          onSelected:
              facilityController.selectArea,
        ),
        FacilityOperatingStatusFilter(
          selectedFilter:
              facilityController
                  .selectedOperatingFilter,
          operatingCount:
              facilityController
                  .operatingFacilityCount,
          closedCount:
              facilityController
                  .closedFacilityCount,
          permanentlyClosedCount:
              facilityController
                  .permanentlyClosedFacilityCount,
          onSelected:
              facilityController
                  .selectOperatingFilter,
        ),
        FacilitySortSelector(
          selectedSortType:
              facilityController.selectedSortType,
          onSelected:
              facilityController.selectSortType,
        ),
        if (hasChangedConditions)
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (facilityController
                    .hasActiveFilters)
                  TextButton.icon(
                    onPressed: onClearFilters,
                    icon: const Icon(
                      Icons
                          .filter_alt_off_outlined,
                      size: 17,
                    ),
                    label: const Text(
                      '絞り込みを解除',
                    ),
                  ),
                TextButton.icon(
                  onPressed: onResetAll,
                  icon: const Icon(
                    Icons.restart_alt,
                    size: 17,
                  ),
                  label: const Text(
                    'すべて初期状態に戻す',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ParkSwitchButton extends StatelessWidget {
  const _ParkSwitchButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colorScheme.primaryContainer
          : colorScheme
              .surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(10),
        side: BorderSide(
          color: selected
              ? colorScheme.primary
              : colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap:
            selected ? null : onPressed,
        child: SizedBox(
          height: 36,
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
              ),
              const SizedBox(
                width: 5,
              ),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FacilityCountRow
    extends StatelessWidget {
  const _FacilityCountRow({
    required this.displayedCount,
    required this.selectedCount,
    required this.totalCount,
    required this.sortLabel,
  });

  final int displayedCount;
  final int selectedCount;
  final int totalCount;
  final String sortLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment:
          WrapCrossAlignment.center,
      children: [
        _CountInformation(
          icon:
              Icons.list_alt_outlined,
          label:
              '表示 $displayedCount件',
          color:
              colorScheme.onSurfaceVariant,
        ),
        _CountInformation(
          icon:
              Icons.location_city_outlined,
          label:
              '全体 $totalCount件',
          color:
              colorScheme.onSurfaceVariant,
        ),
        _CountInformation(
          icon: Icons
              .playlist_add_check_outlined,
          label:
              '選択済み $selectedCount件',
          color:
              colorScheme.onSurfaceVariant,
        ),
        _CountInformation(
          icon:
              Icons.sort_outlined,
          label: sortLabel,
          color:
              colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _CountInformation
    extends StatelessWidget {
  const _CountInformation({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 17,
          color: color,
        ),
        const SizedBox(
          width: 5,
        ),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
                color: color,
              ),
        ),
      ],
    );
  }
}

String _parkName(
  String parkId,
) {
  return switch (parkId) {
    'tokyo_disneyland' =>
      '東京ディズニーランド',
    'tokyo_disneysea' =>
      '東京ディズニーシー',
    _ => parkId,
  };
}

IconData _parkIcon(
  String parkId,
) {
  return switch (parkId) {
    'tokyo_disneyland' =>
      Icons.castle_outlined,
    'tokyo_disneysea' =>
      Icons.water_outlined,
    _ => Icons.park_outlined,
  };
}