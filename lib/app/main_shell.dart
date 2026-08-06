import 'package:flutter/material.dart';

import '../core/theme/app_icons.dart';
import '../core/utils/japanese_search_normalizer.dart';
import '../domain/entities/facility.dart';
import '../features/home/home_screen.dart';
import '../features/plan_editor/plan_editor_screen.dart';
import '../features/plan_review/plan_review_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/today/today_plan_screen.dart';
import '../features/wish_list/wish_list_screen.dart';
import 'dependency/service_locator.dart';
import 'state/app_state.dart';
import 'state/app_state_scope.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() {
    return _MainShellState();
  }
}

class _MainShellState extends State<MainShell> {
  static const double _navigationRailBreakpoint = 900;

  static const int _homeIndex = 0;
  static const int _settingsIndex = 1;
  static const int _wishListIndex = 2;
  static const int _editorIndex = 3;
  static const int _reviewIndex = 4;
  static const int _todayIndex = 5;

  int _currentIndex = _homeIndex;
  bool _wishListCanContinue = false;

  late final TextEditingController _editorSearchController;
  late final FocusNode _editorSearchFocusNode;

  List<Facility> _searchFacilities = const [];
  bool _isLoadingSearchFacilities = false;

  static const List<_MainDestination> _destinations = [
    _MainDestination(
      title: 'ホーム',
      navigationLabel: 'ホーム',
      subtitle: '旅行準備とプラン作成の進行状況を確認します。',
      icon: AppIcons.home,
      selectedIcon: AppIcons.homeSelected,
    ),
    _MainDestination(
      title: '旅行設定',
      navigationLabel: '設定',
      subtitle: '来園日・パーク・時間・利用条件を最初に設定します。',
      icon: AppIcons.settings,
      selectedIcon: AppIcons.settingsSelected,
    ),
    _MainDestination(
      title: 'やりたいこと',
      navigationLabel: 'やりたいこと',
      subtitle: '乗りたい・見たい・飲みたい・食べたいものを選びます。',
      icon: Icons.favorite_border,
      selectedIcon: Icons.favorite,
    ),
    _MainDestination(
      title: 'プラン候補確認',
      navigationLabel: '候補',
      subtitle: 'やりたいことから抽出された施設を確認・微調整します。',
      icon: AppIcons.planEditor,
      selectedIcon: AppIcons.planEditorSelected,
    ),
    _MainDestination(
      title: 'プラン確認',
      navigationLabel: 'プラン',
      subtitle: '候補施設から作成した一日のプランを確認・調整します。',
      icon: AppIcons.planReview,
      selectedIcon: AppIcons.planReviewSelected,
    ),
    _MainDestination(
      title: '当日の予定',
      navigationLabel: '当日',
      subtitle: '採用したプランを現地向け表示で確認します。',
      icon: AppIcons.today,
      selectedIcon: AppIcons.todaySelected,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _editorSearchController = TextEditingController();
    _editorSearchFocusNode = FocusNode();

    _loadSearchFacilities();
  }

  @override
  void dispose() {
    _editorSearchController.dispose();
    _editorSearchFocusNode.dispose();

    super.dispose();
  }

  Future<void> _loadSearchFacilities() async {
    if (_isLoadingSearchFacilities) {
      return;
    }

    _isLoadingSearchFacilities = true;

    try {
      final facilities = await ServiceLocator.facilityRepository
          .getFacilities();

      if (!mounted) {
        return;
      }

      setState(() {
        _searchFacilities = List<Facility>.unmodifiable(facilities);
      });
    } catch (error, stackTrace) {
      debugPrint('検索候補用の施設データ読み込みに失敗しました: $error');

      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isLoadingSearchFacilities = false;
    }
  }

  void _onDestinationSelected(int index) {
    if (index < 0 || index >= _destinations.length || _currentIndex == index) {
      return;
    }

    _editorSearchFocusNode.unfocus();

    setState(() {
      _currentIndex = index;
    });
  }

  void _goToHome() {
    _onDestinationSelected(_homeIndex);
  }

  void _goToSettings() {
    _onDestinationSelected(_settingsIndex);
  }

  void _goToWishList() {
    _onDestinationSelected(_wishListIndex);
  }

  void _goToEditor() {
    _onDestinationSelected(_editorIndex);
  }

  void _goToReview() {
    _onDestinationSelected(_reviewIndex);
  }

  void _goToToday() {
    _onDestinationSelected(_todayIndex);
  }

  void _setWishListCanContinue(bool value) {
    if (_wishListCanContinue == value) {
      return;
    }
    setState(() => _wishListCanContinue = value);
  }

  void _clearEditorSearch() {
    _editorSearchController.clear();
    _editorSearchFocusNode.requestFocus();
  }

  void _selectSearchSuggestion(String suggestion) {
    _editorSearchController
      ..text = suggestion
      ..selection = TextSelection.collapsed(offset: suggestion.length);

    _editorSearchFocusNode.unfocus();
  }

  List<String> _searchOptionsForPark(String parkId) {
    final names = _searchFacilities
        .where((facility) => facility.parkId == parkId)
        .map((facility) => facility.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);

    names.sort();

    return List<String>.unmodifiable(names);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    final useNavigationRail =
        mediaQuery.size.width >= _navigationRailBreakpoint;

    final destination = _destinations[_currentIndex];
    final appState = AppStateScope.of(context);

    final flowState = _PlannerFlowState.fromAppState(appState);

    final isEditorScreen = _currentIndex == _editorIndex;

    final editorSearchOptions = _searchOptionsForPark(
      appState.tripSettings.parkId,
    );

    if (useNavigationRail) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              _DesktopNavigation(
                currentIndex: _currentIndex,
                flowState: flowState,
                onDestinationSelected: _onDestinationSelected,
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: Column(
                  children: [
                    _PageHeader(
                      title: destination.title,
                      subtitle: destination.subtitle,
                      icon: destination.selectedIcon,
                      compact: false,
                      searchController: isEditorScreen
                          ? _editorSearchController
                          : null,
                      searchFocusNode: isEditorScreen
                          ? _editorSearchFocusNode
                          : null,
                      searchOptions: isEditorScreen
                          ? editorSearchOptions
                          : const [],
                      onClearSearch: isEditorScreen ? _clearEditorSearch : null,
                      onSearchSuggestionSelected: isEditorScreen
                          ? _selectSearchSuggestion
                          : null,
                    ),
                    const Divider(height: 1),
                    Expanded(child: _buildScreenStack()),
                    if (_shouldShowFlowBar)
                      _PlannerFlowActionBar(
                        currentIndex: _currentIndex,
                        flowState: flowState,
                        wishListCanContinue: _wishListCanContinue,
                        compact: false,
                        onHomePressed: _goToHome,
                        onSettingsPressed: _goToSettings,
                        onWishListPressed: _goToWishList,
                        onEditorPressed: _goToEditor,
                        onReviewPressed: _goToReview,
                        onTodayPressed: _goToToday,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _PageHeader(
              title: destination.title,
              subtitle: destination.subtitle,
              icon: destination.selectedIcon,
              compact: true,
              searchController: isEditorScreen ? _editorSearchController : null,
              searchFocusNode: isEditorScreen ? _editorSearchFocusNode : null,
              searchOptions: isEditorScreen ? editorSearchOptions : const [],
              onClearSearch: isEditorScreen ? _clearEditorSearch : null,
              onSearchSuggestionSelected: isEditorScreen
                  ? _selectSearchSuggestion
                  : null,
            ),
            const Divider(height: 1),
            Expanded(child: _buildScreenStack()),
            if (_shouldShowFlowBar)
              _PlannerFlowActionBar(
                currentIndex: _currentIndex,
                flowState: flowState,
                wishListCanContinue: _wishListCanContinue,
                compact: true,
                onHomePressed: _goToHome,
                onSettingsPressed: _goToSettings,
                onWishListPressed: _goToWishList,
                onEditorPressed: _goToEditor,
                onReviewPressed: _goToReview,
                onTodayPressed: _goToToday,
              ),
          ],
        ),
      ),
      bottomNavigationBar: _MobileNavigation(
        currentIndex: _currentIndex,
        flowState: flowState,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }

  bool get _shouldShowFlowBar {
    return true;
  }

  Widget _buildScreenStack() {
    return IndexedStack(
      index: _currentIndex,
      children: [
        HomeScreen(
          onWishListPressed: _goToWishList,
          onEditPlanPressed: _goToEditor,
          onReviewPlanPressed: _goToReview,
          onTodayPlanPressed: _goToToday,
          onSettingsPressed: _goToSettings,
        ),
        const SettingsScreen(),
        WishListScreen(
          onCandidateReviewPressed: _goToEditor,
          onFlowContinueAvailabilityChanged: _setWishListCanContinue,
        ),
        PlanEditorScreen(
          searchController: _editorSearchController,
          onWishListPressed: _goToWishList,
        ),
        const PlanReviewScreen(),
        const TodayPlanScreen(),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.compact,
    required this.searchOptions,
    this.searchController,
    this.searchFocusNode,
    this.onClearSearch,
    this.onSearchSuggestionSelected,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool compact;

  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;
  final List<String> searchOptions;
  final VoidCallback? onClearSearch;
  final ValueChanged<String>? onSearchSuggestionSelected;

  bool get _showsSearch {
    return searchController != null && searchFocusNode != null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 12 : 24,
          compact ? 7 : 11,
          compact ? 12 : 24,
          compact ? 7 : 10,
        ),
        child: Row(
          children: [
            Container(
              width: compact ? 34 : 40,
              height: compact ? 34 : 40,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(compact ? 10 : 12),
              ),
              alignment: Alignment.center,
              child: Icon(
                _showsSearch ? Icons.search : icon,
                size: compact ? 19 : 22,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _showsSearch
                  ? _HeaderSearchField(
                      controller: searchController!,
                      focusNode: searchFocusNode!,
                      compact: compact,
                      options: searchOptions,
                      onClear: onClearSearch,
                      onSuggestionSelected: onSearchSuggestionSelected,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: compact
                              ? Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)
                              : Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (!compact) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderSearchField extends StatelessWidget {
  const _HeaderSearchField({
    required this.controller,
    required this.focusNode,
    required this.compact,
    required this.options,
    required this.onClear,
    required this.onSuggestionSelected,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool compact;
  final List<String> options;
  final VoidCallback? onClear;
  final ValueChanged<String>? onSuggestionSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: (option) => option,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim();

        if (query.isEmpty) {
          return const Iterable<String>.empty();
        }

        return options
            .where((option) {
              return JapaneseSearchNormalizer.matchesAny(
                query: query,
                targets: [option],
              );
            })
            .take(8);
      },
      onSelected: (option) {
        onSuggestionSelected?.call(option);
      },
      fieldViewBuilder:
          (context, fieldController, fieldFocusNode, onFieldSubmitted) {
            return ValueListenableBuilder<TextEditingValue>(
              valueListenable: fieldController,
              builder: (context, value, child) {
                final hasText = value.text.trim().isNotEmpty;

                return SizedBox(
                  height: compact ? 40 : 44,
                  child: TextField(
                    controller: fieldController,
                    focusNode: fieldFocusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      onFieldSubmitted();
                      fieldFocusNode.unfocus();
                    },
                    decoration: InputDecoration(
                      hintText: compact ? '施設名を検索' : '施設名・カテゴリ・エリア・営業状態を検索',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: hasText
                          ? IconButton(
                              tooltip: '検索文字を消去',
                              onPressed: onClear,
                              icon: const Icon(Icons.close, size: 18),
                            )
                          : null,
                      filled: true,
                      fillColor: colorScheme.surfaceContainerLowest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: BorderSide(
                          color: colorScheme.outline,
                          width: 1.1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
      optionsViewOpenDirection: OptionsViewOpenDirection.down,
      optionsViewBuilder: (context, onSelected, displayedOptions) {
        final optionList = displayedOptions.toList(growable: false);

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: compact ? 310 : 520,
                maxHeight: compact ? 240 : 300,
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: optionList.length,
                separatorBuilder: (context, index) {
                  return Divider(height: 1, color: colorScheme.outlineVariant);
                },
                itemBuilder: (context, index) {
                  final option = optionList[index];

                  return InkWell(
                    onTap: () {
                      onSelected(option);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.place_outlined,
                              size: 17,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              option,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.north_west,
                            size: 17,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlannerFlowActionBar extends StatelessWidget {
  const _PlannerFlowActionBar({
    required this.currentIndex,
    required this.flowState,
    required this.wishListCanContinue,
    required this.compact,
    required this.onHomePressed,
    required this.onSettingsPressed,
    required this.onWishListPressed,
    required this.onEditorPressed,
    required this.onReviewPressed,
    required this.onTodayPressed,
  });

  final int currentIndex;
  final _PlannerFlowState flowState;
  final bool wishListCanContinue;
  final bool compact;

  final VoidCallback onHomePressed;
  final VoidCallback onSettingsPressed;
  final VoidCallback onWishListPressed;
  final VoidCallback onEditorPressed;
  final VoidCallback onReviewPressed;
  final VoidCallback onTodayPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final action = _resolveAction();

    return Material(
      color: colorScheme.surface,
      elevation: 0,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          compact ? 12 : 20,
          compact ? 7 : 11,
          compact ? 12 : 20,
          compact ? 7 : 11,
        ),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: compact
            ? _CompactFlowActions(action: action)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PlannerProgressIndicator(
                    currentIndex: currentIndex,
                    flowState: flowState,
                  ),
                  const SizedBox(height: 9),
                  _DesktopFlowActions(
                    action: action,
                    currentIndex: currentIndex,
                    flowState: flowState,
                    onHomePressed: onHomePressed,
                    onSettingsPressed: onSettingsPressed,
                    onWishListPressed: onWishListPressed,
                    onEditorPressed: onEditorPressed,
                    onReviewPressed: onReviewPressed,
                    onTodayPressed: onTodayPressed,
                  ),
                ],
              ),
      ),
    );
  }

  _PlannerFlowAction _resolveHomeAction() {
    if (flowState.selectedWishCount == 0) {
      return _PlannerFlowAction(
        title: 'AIとプランを作る',
        description: 'まずは、乗りたい・見たい・食べたい体験を選びます。',
        icon: Icons.auto_awesome_outlined,
        onPressed: onWishListPressed,
      );
    }

    if (flowState.selectedFacilityCount == 0) {
      return _PlannerFlowAction(
        title: 'AI候補を確認',
        description: '${flowState.selectedWishCount}件の希望から抽出した候補を調整します。',
        icon: Icons.checklist_outlined,
        onPressed: onEditorPressed,
      );
    }

    if (!flowState.hasCurrentSchedule) {
      return _PlannerFlowAction(
        title: 'プランを生成・確認',
        description: '${flowState.selectedFacilityCount}件の候補から一日のプランを作成します。',
        icon: Icons.route_outlined,
        onPressed: onReviewPressed,
      );
    }

    return _PlannerFlowAction(
      title: '当日の予定を見る',
      description: '${flowState.scheduleItemCount}件の予定を時系列で確認します。',
      icon: Icons.event_available_outlined,
      onPressed: onTodayPressed,
    );
  }

  _PlannerFlowAction _resolveAction() {
    return switch (currentIndex) {
      _MainShellState._homeIndex => _resolveHomeAction(),
      _MainShellState._settingsIndex => _PlannerFlowAction(
        title: 'やりたいことを選ぶ',
        description: '設定したパークで、達成したいことを選びます。',
        icon: Icons.favorite_border,
        onPressed: onWishListPressed,
      ),
      _MainShellState._wishListIndex => wishListCanContinue
          ? _PlannerFlowAction(
              title: 'プラン候補を確認',
              description: flowState.selectedWishCount == 0
                  ? '一覧から選んだ内容を確認し、候補施設を調整します。'
                  : '${flowState.selectedWishCount}件のやりたいことから販売店舗・施設を抽出します。',
              icon: Icons.checklist_outlined,
              onPressed: onEditorPressed,
            )
          : const _PlannerFlowAction(
              title: 'AI候補を作成してください',
              description: '回答確認画面の「この回答でAI候補を作成」を押してください。',
              icon: Icons.auto_awesome_outlined,
              onPressed: null,
            ),
      _MainShellState._editorIndex =>
        flowState.selectedFacilityCount == 0
            ? _PlannerFlowAction(
                title: 'やりたいことへ戻る',
                description: '希望を選び、AI候補を作成してください。',
                icon: Icons.favorite_border,
                onPressed: onWishListPressed,
              )
            : _PlannerFlowAction(
                title: 'プランを生成・確認',
                description:
                    '${flowState.selectedFacilityCount}件の候補から一日のプランを作成します。',
                icon: Icons.arrow_forward,
                onPressed: onReviewPressed,
              ),
      _MainShellState._reviewIndex =>
        flowState.hasCurrentSchedule
            ? _PlannerFlowAction(
                title: '当日の予定へ',
                description: '${flowState.scheduleItemCount}件の予定を現地表示で確認します。',
                icon: Icons.event_available_outlined,
                onPressed: onTodayPressed,
              )
            : _PlannerFlowAction(
                title: '候補を見直す',
                description: 'やりたいことから抽出した施設や手動追加施設を確認します。',
                icon: Icons.arrow_back,
                onPressed: onEditorPressed,
              ),
      _MainShellState._todayIndex => _PlannerFlowAction(
        title: 'プラン確認へ戻る',
        description: '生成内容の確認や再生成を行います。',
        icon: Icons.arrow_back,
        onPressed: onReviewPressed,
      ),
      _ => _PlannerFlowAction(
        title: 'ホームへ',
        description: '現在の旅行準備状況を確認します。',
        icon: Icons.home_outlined,
        onPressed: onHomePressed,
      ),
    };
  }
}

class _CompactFlowActions extends StatelessWidget {
  const _CompactFlowActions({required this.action});

  final _PlannerFlowAction action;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: action.onPressed,
        icon: Icon(action.icon, size: 18),
        label: Text(action.title),
      ),
    );
  }
}

class _DesktopFlowActions extends StatelessWidget {
  const _DesktopFlowActions({
    required this.action,
    required this.currentIndex,
    required this.flowState,
    required this.onHomePressed,
    required this.onSettingsPressed,
    required this.onWishListPressed,
    required this.onEditorPressed,
    required this.onReviewPressed,
    required this.onTodayPressed,
  });

  final _PlannerFlowAction action;
  final int currentIndex;
  final _PlannerFlowState flowState;
  final VoidCallback onHomePressed;
  final VoidCallback onSettingsPressed;
  final VoidCallback onWishListPressed;
  final VoidCallback onEditorPressed;
  final VoidCallback onReviewPressed;
  final VoidCallback onTodayPressed;

  @override
  Widget build(BuildContext context) {
    final showHomeShortcuts = currentIndex == _MainShellState._homeIndex;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                action.title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                action.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        if (showHomeShortcuts) ...[
          _FlowShortcutButton(
            icon: Icons.favorite_border,
            label: 'やりたいこと',
            onPressed: onWishListPressed,
            emphasized: flowState.selectedWishCount == 0,
          ),
          const SizedBox(width: 8),
          _FlowShortcutButton(
            icon: Icons.checklist_outlined,
            label: '候補確認',
            onPressed: onEditorPressed,
            emphasized:
                flowState.selectedWishCount > 0 &&
                flowState.selectedFacilityCount == 0,
          ),
          const SizedBox(width: 8),
          _FlowShortcutButton(
            icon: Icons.tune_outlined,
            label: '来園設定',
            onPressed: onSettingsPressed,
          ),
          if (flowState.hasCurrentSchedule) ...[
            const SizedBox(width: 8),
            _FlowShortcutButton(
              icon: Icons.event_available_outlined,
              label: '当日の予定',
              onPressed: onTodayPressed,
            ),
          ] else if (flowState.selectedFacilityCount > 0) ...[
            const SizedBox(width: 8),
            _FlowShortcutButton(
              icon: Icons.route_outlined,
              label: 'プラン確認',
              onPressed: onReviewPressed,
              emphasized: true,
            ),
          ],
          const SizedBox(width: 12),
        ],
        if (currentIndex == _MainShellState._reviewIndex) ...[
          OutlinedButton.icon(
            onPressed: onEditorPressed,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('編集へ戻る'),
          ),
          const SizedBox(width: 8),
        ],
        if (currentIndex == _MainShellState._todayIndex) ...[
          OutlinedButton.icon(
            onPressed: onHomePressed,
            icon: const Icon(Icons.home_outlined, size: 18),
            label: const Text('ホーム'),
          ),
          const SizedBox(width: 8),
        ],
        FilledButton.icon(
          onPressed: action.onPressed,
          icon: Icon(action.icon, size: 19),
          label: Text(action.title),
        ),
      ],
    );
  }
}

class _FlowShortcutButton extends StatelessWidget {
  const _FlowShortcutButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor:
            emphasized ? colorScheme.primary : colorScheme.onSurfaceVariant,
        backgroundColor: emphasized
            ? colorScheme.primaryContainer.withValues(alpha: 0.5)
            : null,
        side: BorderSide(
          color: emphasized ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class _PlannerProgressIndicator extends StatelessWidget {
  const _PlannerProgressIndicator({
    required this.currentIndex,
    required this.flowState,
  });

  final int currentIndex;
  final _PlannerFlowState flowState;

  @override
  Widget build(BuildContext context) {
    final steps = <_PlannerStep>[
      _PlannerStep(
        label: '旅行設定',
        icon: Icons.tune,
        completed: true,
        active: currentIndex == _MainShellState._settingsIndex,
      ),
      _PlannerStep(
        label: 'やりたいこと',
        icon: Icons.favorite_border,
        completed: flowState.selectedWishCount > 0,
        active: currentIndex == _MainShellState._wishListIndex,
      ),
      _PlannerStep(
        label: '候補確認',
        icon: Icons.checklist_outlined,
        completed: flowState.selectedFacilityCount > 0,
        active: currentIndex == _MainShellState._editorIndex,
      ),
      _PlannerStep(
        label: 'プラン',
        icon: Icons.route_outlined,
        completed: flowState.hasCurrentSchedule,
        active: currentIndex == _MainShellState._reviewIndex,
      ),
      _PlannerStep(
        label: '当日',
        icon: Icons.event_available_outlined,
        completed: false,
        active: currentIndex == _MainShellState._todayIndex,
      ),
    ];

    return Row(
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          Expanded(child: _PlannerStepView(step: steps[index])),
          if (index < steps.length - 1)
            _PlannerStepConnector(completed: steps[index].completed),
        ],
      ],
    );
  }
}

class _PlannerStepView extends StatelessWidget {
  const _PlannerStepView({required this.step});

  final _PlannerStep step;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final Color backgroundColor;
    final Color foregroundColor;
    final IconData icon;

    if (step.active) {
      backgroundColor = colorScheme.primary;
      foregroundColor = colorScheme.onPrimary;
      icon = step.icon;
    } else if (step.completed) {
      backgroundColor = colorScheme.primaryContainer;
      foregroundColor = colorScheme.onPrimaryContainer;
      icon = Icons.check;
    } else {
      backgroundColor = colorScheme.surfaceContainerHigh;
      foregroundColor = colorScheme.onSurfaceVariant;
      icon = step.icon;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: step.active
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: foregroundColor),
        ),
        const SizedBox(height: 4),
        Text(
          step.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: step.active
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            fontWeight: step.active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PlannerStepConnector extends StatelessWidget {
  const _PlannerStepConnector({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      color: completed ? colorScheme.primary : colorScheme.outlineVariant,
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.currentIndex,
    required this.flowState,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final _PlannerFlowState flowState;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 210,
      color: colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.auto_awesome,
                    size: 21,
                    color: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Disney Planner',
                    maxLines: 2,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _MainShellState._destinations.length,
              separatorBuilder: (_, _) {
                return const SizedBox(height: 4);
              },
              itemBuilder: (context, index) {
                final destination = _MainShellState._destinations[index];

                return _DesktopNavigationItem(
                  destination: destination,
                  selected: currentIndex == index,
                  badgeLabel: _badgeForIndex(index),
                  onPressed: () {
                    onDestinationSelected(index);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              '旅行設定から当日確認まで',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _badgeForIndex(int index) {
    return switch (index) {
      _MainShellState._wishListIndex =>
        flowState.selectedWishCount > 0
            ? '${flowState.selectedWishCount}'
            : null,
      _MainShellState._editorIndex =>
        flowState.selectedFacilityCount > 0
            ? '${flowState.selectedFacilityCount}'
            : null,
      _MainShellState._reviewIndex =>
        flowState.hasCurrentSchedule ? '${flowState.scheduleItemCount}' : null,
      _ => null,
    };
  }
}

class _DesktopNavigationItem extends StatelessWidget {
  const _DesktopNavigationItem({
    required this.destination,
    required this.selected,
    required this.badgeLabel,
    required this.onPressed,
  });

  final _MainDestination destination;
  final bool selected;
  final String? badgeLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected ? colorScheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 21,
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  destination.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (badgeLabel != null) ...[
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 22,
                    minHeight: 22,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    badgeLabel!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (selected)
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: colorScheme.onPrimaryContainer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({
    required this.currentIndex,
    required this.flowState,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final _PlannerFlowState flowState;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      height: 62,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        for (
          var index = 0;
          index < _MainShellState._destinations.length;
          index++
        )
          NavigationDestination(
            tooltip: _MainShellState._destinations[index].title,
            icon: _MobileNavigationIcon(
              icon: _MainShellState._destinations[index].icon,
              badgeLabel: _badgeForIndex(index),
            ),
            selectedIcon: _MobileNavigationIcon(
              icon: _MainShellState._destinations[index].selectedIcon,
              badgeLabel: _badgeForIndex(index),
            ),
            label: _MainShellState._destinations[index].navigationLabel,
          ),
      ],
    );
  }

  String? _badgeForIndex(int index) {
    return switch (index) {
      _MainShellState._wishListIndex =>
        flowState.selectedWishCount > 0
            ? '${flowState.selectedWishCount}'
            : null,
      _MainShellState._editorIndex =>
        flowState.selectedFacilityCount > 0
            ? '${flowState.selectedFacilityCount}'
            : null,
      _MainShellState._reviewIndex =>
        flowState.hasCurrentSchedule ? '${flowState.scheduleItemCount}' : null,
      _ => null,
    };
  }
}

class _MobileNavigationIcon extends StatelessWidget {
  const _MobileNavigationIcon({required this.icon, required this.badgeLabel});

  final IconData icon;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: badgeLabel != null,
      label: badgeLabel == null ? null : Text(badgeLabel!),
      child: Icon(icon, size: 21),
    );
  }
}

class _PlannerFlowState {
  const _PlannerFlowState({
    required this.selectedWishCount,
    required this.selectedFacilityCount,
    required this.hasCurrentSchedule,
    required this.scheduleItemCount,
  });

  factory _PlannerFlowState.fromAppState(AppState appState) {
    final parkId = appState.tripSettings.parkId;
    final schedule = appState.daySchedule;

    final hasCurrentSchedule = schedule != null && schedule.parkId == parkId;

    return _PlannerFlowState(
      selectedWishCount: appState.selectedWishCount,
      selectedFacilityCount: appState.selectedFacilityCountForPark(parkId),
      hasCurrentSchedule: hasCurrentSchedule,
      scheduleItemCount: hasCurrentSchedule ? schedule.items.length : 0,
    );
  }

  final int selectedWishCount;
  final int selectedFacilityCount;
  final bool hasCurrentSchedule;
  final int scheduleItemCount;
}

class _PlannerFlowAction {
  const _PlannerFlowAction({
    required this.title,
    required this.description,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onPressed;
}

class _PlannerStep {
  const _PlannerStep({
    required this.label,
    required this.icon,
    required this.completed,
    required this.active,
  });

  final String label;
  final IconData icon;
  final bool completed;
  final bool active;
}

class _MainDestination {
  const _MainDestination({
    required this.title,
    required this.navigationLabel,
    required this.subtitle,
    required this.icon,
    required this.selectedIcon,
  });

  final String title;
  final String navigationLabel;
  final String subtitle;
  final IconData icon;
  final IconData selectedIcon;
}
