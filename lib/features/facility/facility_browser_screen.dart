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
import 'plan_builder_controller.dart';
import 'plan_preference_controller.dart';
import 'widgets/facility_card.dart';
import 'widgets/selected_facility_editor_sheet.dart';
import 'widgets/unified_facility_filter_panel.dart';

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

class _FacilityBrowserScreenState extends State<FacilityBrowserScreen> {
  AppState? _appState;
  FacilityController? _facilityController;
  PlanBuilderController? _planBuilderController;
  PlanPreferenceController? _planPreferenceController;

  late final ScrollController _scrollController;
  late final FocusNode _searchFocusNode;

  bool _isSearchVisible = false;
  bool _parkSynchronizationScheduled = false;

  @override
  void initState() {
    super.initState();

    widget.searchController.addListener(_onExternalSearchChanged);
    _scrollController = ScrollController();
    _searchFocusNode = FocusNode();
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
    facilityController.updateSearchKeyword(widget.searchController.text);
    planBuilderController.addListener(_refresh);
    planPreferenceController.addListener(_refresh);
  }

  void _synchronizeParkFromSettings(AppState appState) {
    final controller = _facilityController;

    if (controller == null) {
      return;
    }

    final settingsParkId = appState.tripSettings.parkId;

    if (settingsParkId.trim().isEmpty ||
        controller.selectedParkId == settingsParkId ||
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
          controller.selectedParkId == latestParkId) {
        return;
      }

      controller.selectPark(latestParkId);
      _clearSearchText();
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

    widget.searchController.removeListener(_onExternalSearchChanged);
    _scrollController.dispose();
    _searchFocusNode.dispose();

    super.dispose();
  }

  void _onExternalSearchChanged() {
    _facilityController?.updateSearchKeyword(widget.searchController.text);
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
    final controller = _facilityController;

    if (controller == null) {
      return;
    }

    controller.clearFilters();
    widget.searchController.clear();
    _searchFocusNode.unfocus();
  }

  void _clearSearchText() {
    widget.searchController.clear();
    _facilityController?.updateSearchKeyword('');
    _searchFocusNode.unfocus();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
    });

    if (_isSearchVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });

      return;
    }

    if (widget.searchController.text.isNotEmpty) {
      _clearSearchText();
    }
  }

  void _changePark(String parkId) {
    final appState = _appState;
    final controller = _facilityController;

    if (appState == null ||
        controller == null ||
        parkId.trim().isEmpty ||
        controller.selectedParkId == parkId) {
      return;
    }

    appState.updateTripSettings(appState.tripSettings.copyWith(parkId: parkId));

    controller.selectPark(parkId);
    _clearSearchText();

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _openSelectedFacilityEditor() {
    final planBuilderController = _planBuilderController;
    final preferenceController = _planPreferenceController;
    final facilityController = _facilityController;

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
          planBuilderController: planBuilderController,
          preferenceController: preferenceController,
          selectedParkId: facilityController.selectedParkId,
          onReviewPlanPressed: widget.onReviewPlanPressed,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = _appState;
    final facilityController = _facilityController;
    final planBuilderController = _planBuilderController;

    if (appState == null ||
        facilityController == null ||
        planBuilderController == null ||
        _planPreferenceController == null) {
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

    final facilities = facilityController.filteredFacilities;

    final selectedCount = planBuilderController.selectedFacilityCountForPark(
      facilityController.selectedParkId,
    );

    return AppScaffold(
      child: Column(
        children: [
          _FixedEditorHeader(
            selectedParkId: facilityController.selectedParkId,
            selectedFacilityCount: selectedCount,
            isSearchVisible: _isSearchVisible,
            onParkChanged: _changePark,
            onSearchPressed: _toggleSearch,
            onSelectedFacilitiesPressed: _openSelectedFacilityEditor,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            child: _isSearchVisible
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: _CompactSearchField(
                      controller: widget.searchController,
                      focusNode: _searchFocusNode,
                      onChanged: facilityController.updateSearchKeyword,
                      onClear: _clearSearchText,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              interactive: true,
              thickness: 5,
              radius: const Radius.circular(8),
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.only(right: 14, bottom: 96),
                children: [
                  UnifiedFacilityFilterPanel(
                    controller: facilityController,
                    onClearFilters: _clearFilters,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _FacilityCountRow(
                    displayedCount: facilities.length,
                    selectedCount: selectedCount,
                    totalCount: facilityController.parkFacilities.length,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '施設一覧',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (facilities.isEmpty)
                    const EmptyState(
                      title: '施設が見つかりません',
                      message: '検索条件、カテゴリ、エリアまたは営業状態を変更してください。',
                      icon: Icons.search_off_outlined,
                    )
                  else
                    for (final facility in facilities) ...[
                      FacilityCard(
                        facility: facility,
                        isSelected: planBuilderController.isSelected(
                          facility.id,
                        ),
                        onAdd: () {
                          _addFacility(facility);
                        },
                        onRemove: () {
                          _removeFacility(facility.id);
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FixedEditorHeader extends StatelessWidget {
  const _FixedEditorHeader({
    required this.selectedParkId,
    required this.selectedFacilityCount,
    required this.isSearchVisible,
    required this.onParkChanged,
    required this.onSearchPressed,
    required this.onSelectedFacilitiesPressed,
  });

  final String selectedParkId;
  final int selectedFacilityCount;
  final bool isSearchVisible;
  final ValueChanged<String> onParkChanged;
  final VoidCallback onSearchPressed;
  final VoidCallback onSelectedFacilitiesPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '編集中：${_parkName(selectedParkId)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: isSearchVisible ? '検索を閉じる' : '施設を検索',
                onPressed: onSearchPressed,
                icon: Icon(isSearchVisible ? Icons.close : Icons.search),
              ),
              const SizedBox(width: 4),
              FilledButton.tonalIcon(
                onPressed: onSelectedFacilitiesPressed,
                icon: const Icon(Icons.edit_note_outlined, size: 18),
                label: Text('選択 $selectedFacilityCount'),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: _ParkSwitchButton(
                  label: 'ランド',
                  icon: Icons.castle_outlined,
                  selected: selectedParkId == 'tokyo_disneyland',
                  onPressed: () {
                    onParkChanged('tokyo_disneyland');
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ParkSwitchButton(
                  label: 'シー',
                  icon: Icons.water_outlined,
                  selected: selectedParkId == 'tokyo_disneysea',
                  onPressed: () {
                    onParkChanged('tokyo_disneysea');
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
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: selected ? null : onPressed,
        child: SizedBox(
          height: 36,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17),
              const SizedBox(width: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactSearchField extends StatelessWidget {
  const _CompactSearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: '施設名・カテゴリ・エリア・営業状態を検索',
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: IconButton(
            tooltip: '検索文字を消去',
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 17),
          ),
        ),
      ),
    );
  }
}

class _FacilityCountRow extends StatelessWidget {
  const _FacilityCountRow({
    required this.displayedCount,
    required this.selectedCount,
    required this.totalCount,
  });

  final int displayedCount;
  final int selectedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _CountInformation(
          icon: Icons.list_alt_outlined,
          label: '表示 $displayedCount件',
          color: colorScheme.onSurfaceVariant,
        ),
        _CountInformation(
          icon: Icons.location_city_outlined,
          label: '全体 $totalCount件',
          color: colorScheme.onSurfaceVariant,
        ),
        _CountInformation(
          icon: Icons.playlist_add_check_outlined,
          label: '選択済み $selectedCount件',
          color: colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _CountInformation extends StatelessWidget {
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
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

String _parkName(String parkId) {
  return switch (parkId) {
    'tokyo_disneyland' => '東京ディズニーランド',
    'tokyo_disneysea' => '東京ディズニーシー',
    _ => parkId,
  };
}

IconData _parkIcon(String parkId) {
  return switch (parkId) {
    'tokyo_disneyland' => Icons.castle_outlined,
    'tokyo_disneysea' => Icons.water_outlined,
    _ => Icons.park_outlined,
  };
}
