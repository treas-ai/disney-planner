import 'package:flutter/material.dart';

import '../../app/dependency/service_locator.dart';
import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/entities/wish_item.dart';
import '../../domain/enums/wish_item_category.dart';
import 'guided_planning_controller.dart';
import 'wish_list_controller.dart';

class WishListScreen extends StatefulWidget {
  const WishListScreen({super.key, required this.onCandidateReviewPressed});

  final VoidCallback onCandidateReviewPressed;

  @override
  State<WishListScreen> createState() => _WishListScreenState();
}

class _WishListScreenState extends State<WishListScreen> {
  WishListController? _wishController;
  GuidedPlanningController? _chatController;
  bool _showList = false;
  bool _isApplyingGuidedResult = false;
  bool _showGuidedProcessing = false;
  int _guidedApplyRequestId = 0;
  final Set<String> _guidedExplicitIds = <String>{};

  WishListController get wishController => _wishController!;
  GuidedPlanningController get chatController => _chatController!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = AppStateScope.of(context);
    _wishController ??= WishListController(
      appState: appState,
      facilityRepository: ServiceLocator.facilityRepository,
    )..load();
    _chatController ??= GuidedPlanningController(appState: appState);
  }


  @override
  void dispose() {
    _wishController?.dispose();
    _chatController?.dispose();
    super.dispose();
  }

  Future<void> _applyAndContinue() async {
    final added = await wishController.applySelectedItemsToPlan();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added == 0 ? '候補施設はすでに反映されています。' : '$added件の施設をプラン候補へ追加しました。',
        ),
      ),
    );
    widget.onCandidateReviewPressed();
  }

  Future<void> _applyChatResult() async {
    if (_isApplyingGuidedResult) {
      return;
    }

    final requestId = ++_guidedApplyRequestId;
    setState(() {
      _isApplyingGuidedResult = true;
      _showGuidedProcessing = false;
    });

    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted ||
          requestId != _guidedApplyRequestId ||
          !_isApplyingGuidedResult) {
        return;
      }
      setState(() => _showGuidedProcessing = true);
    });

    try {
      // UIスレッドへ描画機会を渡しますが、演出目的の待機時間は追加しません。
      await Future<void>.delayed(Duration.zero);
      final selectedByQuestion = chatController.applyToWishList(wishController.allItems);
      wishController.appState.selectWishItems(_guidedExplicitIds);
      final selected = selectedByQuestion + _guidedExplicitIds.length;
      if (!mounted || requestId != _guidedApplyRequestId) {
        return;
      }

      setState(() => _showList = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$selected件をやりたいことへ反映しました。')),
      );
    } finally {
      if (mounted && requestId == _guidedApplyRequestId) {
        setState(() {
          _isApplyingGuidedResult = false;
          _showGuidedProcessing = false;
        });
      }
    }
  }

  Future<void> _resetWishSelection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('やりたいことをリセットしますか？'),
        content: const Text('質問の回答と現在の選択をすべて解除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('リセット'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    chatController.restart(clearWishSelection: true);
    setState(() {
      _showList = false;
      _guidedExplicitIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('質問の回答とやりたいことの選択をリセットしました。')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([wishController, chatController, appState]),
      builder: (context, child) {
        if (wishController.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            _ModeSwitcher(
              showList: _showList,
              onWizardPressed: () => setState(() => _showList = false),
              onListPressed: () => setState(() => _showList = true),
              onResetPressed: _resetWishSelection,
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _showList
                        ? _CompactWishList(
                            controller: wishController,
                            onContinue: _applyAndContinue,
                          )
                        : _GuidedWizard(
                            controller: chatController,
                            items: wishController.allItems,
                            selectedIds: _guidedExplicitIds,
                            onToggleItem: (id) {
                              setState(() {
                                if (!_guidedExplicitIds.add(id)) {
                                  _guidedExplicitIds.remove(id);
                                }
                              });
                            },
                            isApplying: _isApplyingGuidedResult,
                            onApply: _applyChatResult,
                          ),
                  ),
                  if (_showGuidedProcessing)
                    const Positioned.fill(child: _GuidedProcessingOverlay()),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({
    required this.showList,
    required this.onWizardPressed,
    required this.onListPressed,
    required this.onResetPressed,
  });

  final bool showList;
  final VoidCallback onWizardPressed;
  final VoidCallback onListPressed;
  final VoidCallback onResetPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: showList
                ? OutlinedButton.icon(
                    onPressed: onWizardPressed,
                    icon: const Icon(Icons.question_answer_outlined),
                    label: const Text('質問で決める'),
                  )
                : FilledButton.tonalIcon(
                    onPressed: onWizardPressed,
                    icon: const Icon(Icons.question_answer),
                    label: const Text('質問で決める'),
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: showList
                ? FilledButton.tonalIcon(
                    onPressed: onListPressed,
                    icon: const Icon(Icons.checklist),
                    label: const Text('一覧で確認'),
                  )
                : OutlinedButton.icon(
                    onPressed: onListPressed,
                    icon: const Icon(Icons.checklist_outlined),
                    label: const Text('一覧で確認'),
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onResetPressed,
            icon: const Icon(Icons.restart_alt),
            label: const Text('リセット'),
          ),
        ],
      ),
    );
  }
}

class _GuidedWizard extends StatelessWidget {
  const _GuidedWizard({
    required this.controller,
    required this.items,
    required this.selectedIds,
    required this.onToggleItem,
    required this.isApplying,
    required this.onApply,
  });

  final GuidedPlanningController controller;
  final List<WishItem> items;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleItem;
  final bool isApplying;
  final Future<void> Function() onApply;

  @override
  Widget build(BuildContext context) {
    final completed = controller.step == GuidedPlanningStep.completed;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (controller.canGoBack)
                        IconButton(
                          tooltip: '前の質問へ戻る',
                          onPressed: controller.goBack,
                          icon: const Icon(Icons.arrow_back),
                        ),
                      Text(
                        completed
                            ? '希望の確認'
                            : 'ステップ ${controller.currentStepNumber} / ${controller.totalStepCount}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => controller.restart(
                          clearWishSelection: true,
                        ),
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: const Text('最初から'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '対象パーク：${controller.parkName}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  LinearProgressIndicator(
                    value:
                        controller.currentStepNumber /
                        controller.totalStepCount,
                  ),
                  if (completed) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _CompletedWishSummary(controller: controller),
                    const SizedBox(height: AppSpacing.sm),
                  ] else ...[
                    const SizedBox(height: AppSpacing.md),
                    Icon(
                      _stepIcon(controller.step),
                      size: 30,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      controller.question,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controller.selectionGuide,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Expanded(
                    child: completed
                        ? _SpecificWishPicker(
                            controller: controller,
                            parkId: controller.appState.tripSettings.parkId,
                            items: items,
                            selectedIds: selectedIds,
                            onToggleItem: onToggleItem,
                            isApplying: isApplying,
                            onApply: onApply,
                          )
                        : _QuestionOptions(controller: controller),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _stepIcon(GuidedPlanningStep step) => switch (step) {
    GuidedPlanningStep.welcome => Icons.waving_hand_outlined,
    GuidedPlanningStep.mainFocus => Icons.auto_awesome_outlined,
    GuidedPlanningStep.seasonalEvent => Icons.celebration_outlined,
    GuidedPlanningStep.freeDrink => Icons.local_drink_outlined,
    GuidedPlanningStep.foodInterests => Icons.restaurant_menu_outlined,
    GuidedPlanningStep.entertainment => Icons.attractions_outlined,
    GuidedPlanningStep.completed => Icons.check_circle_outline,
  };
}

class _QuestionOptions extends StatelessWidget {
  const _QuestionOptions({required this.controller});

  final GuidedPlanningController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 480
            ? 2
            : 1;
        final optionCount = controller.options.length;
        final rows = (optionCount / columns).ceil();
        final actionHeight = controller.isMultiSelectStep ? 52.0 : 0.0;
        final availableHeight = constraints.maxHeight - actionHeight;
        final tileHeight = ((availableHeight - (rows - 1) * AppSpacing.sm) / rows)
            .clamp(66.0, 96.0);

        return Column(
          children: [
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  mainAxisExtent: tileHeight,
                ),
                itemCount: optionCount,
                itemBuilder: (context, index) {
                  final option = controller.options[index];
                  return _OptionTile(
                    label: option,
                    description: controller.optionDescription(option),
                    icon: controller.optionIcon(option),
                    selected:
                        controller.isMultiSelectStep &&
                        controller.isOptionSelected(option),
                    onTap: () => controller.answer(option),
                  );
                },
              ),
            ),
            if (controller.isMultiSelectStep) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  onPressed: controller.confirmCurrentMultiSelection,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('選択内容を確定して次へ'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              width: selected ? 2 : 1,
              color: selected ? colors.primary : colors.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primary.withValues(alpha: 0.12)
                      : colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  selected ? Icons.check_rounded : icon,
                  size: 20,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.15,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class _CompletedWishSummary extends StatelessWidget {
  const _CompletedWishSummary({required this.controller});

  final GuidedPlanningController controller;

  @override
  Widget build(BuildContext context) {
    final items = controller.summaryItems;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '回答内容',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final item in items)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          avatar: const Icon(Icons.check, size: 15),
                          label: Text(item),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecificWishPicker extends StatefulWidget {
  const _SpecificWishPicker({
    required this.controller,
    required this.parkId,
    required this.items,
    required this.selectedIds,
    required this.onToggleItem,
    required this.isApplying,
    required this.onApply,
  });

  final GuidedPlanningController controller;
  final String parkId;
  final List<WishItem> items;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleItem;
  final bool isApplying;
  final Future<void> Function() onApply;

  @override
  State<_SpecificWishPicker> createState() => _SpecificWishPickerState();
}

class _SpecificWishPickerState extends State<_SpecificWishPicker>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _query = '';
  bool _showAll = false;

  static const _tabs = <({String label, IconData icon})>[
    (label: 'アトラクション', icon: Icons.attractions_outlined),
    (label: 'ショー・パレード', icon: Icons.theater_comedy_outlined),
    (label: 'フード・ドリンク', icon: Icons.restaurant_outlined),
    (label: 'グリーティング', icon: Icons.emoji_people_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: _initialTabIndex(),
    );
  }

  int _initialTabIndex() {
    final controller = widget.controller;
    if (controller.wantsEntertainment || controller.wantsSeasonalEntertainment) {
      return 1;
    }
    if (controller.preferredCategories.any(_foodCategories.contains) ||
        controller.wantsFeaturedFreeDrinkMenus) {
      return 2;
    }
    if (controller.preferredCategories.contains(WishItemCategory.greeting)) {
      return 3;
    }
    return 0;
  }

  bool _matchesQuestionResult(WishItem item, int tabIndex) {
    final controller = widget.controller;
    final isSeasonal = item.eventPackId != 'facility_master';
    return switch (tabIndex) {
      0 => controller.wantsAttractions || controller.wantsBalancedPlan,
      1 => controller.wantsEntertainment ||
          (controller.wantsSeasonalEntertainment && isSeasonal),
      2 => controller.preferredCategories.contains(item.category) ||
          (controller.wantsSeasonalMenus && isSeasonal) ||
          (controller.wantsFeaturedFreeDrinkMenus && item.freeDrinkEligible) ||
          (controller.usesFreeDrink && item.freeDrinkEligible),
      _ => controller.preferredCategories.contains(WishItemCategory.greeting) ||
          controller.wantsBalancedPlan,
    };
  }

  int _recommendationRank(WishItem item, int tabIndex) {
    var score = 0;
    final controller = widget.controller;
    final isSeasonal = item.eventPackId != 'facility_master';
    if (widget.selectedIds.contains(item.id)) score += 1000;
    if (_matchesQuestionResult(item, tabIndex)) score += 100;
    if (isSeasonal &&
        (controller.wantsSeasonalMenus ||
            controller.wantsSeasonalEntertainment)) {
      score += 30;
    }
    if (item.freeDrinkEligible &&
        (controller.usesFreeDrink || controller.wantsFeaturedFreeDrinkMenus)) {
      score += 40;
    }
    return score;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<WishItem> _itemsFor(int tabIndex) {
    final normalized = _query.trim().toLowerCase();
    final all = widget.items.where((item) {
      if (item.parkId != widget.parkId) return false;
      final categoryMatch = switch (tabIndex) {
        0 => item.category == WishItemCategory.attraction,
        1 => item.category == WishItemCategory.entertainment,
        2 => _foodCategories.contains(item.category),
        _ => item.category == WishItemCategory.greeting,
      };
      if (!categoryMatch) return false;
      if (normalized.isEmpty) return true;
      return '${item.name} ${item.venueNames.join(' ')}'
          .toLowerCase()
          .contains(normalized);
    }).toList(growable: false);

    all.sort((a, b) {
      final rankCompare = _recommendationRank(
        b,
        tabIndex,
      ).compareTo(_recommendationRank(a, tabIndex));
      if (rankCompare != 0) return rankCompare;
      return a.name.compareTo(b.name);
    });

    if (_showAll || normalized.isNotEmpty) return all;
    final recommended = all
        .where(
          (item) =>
              widget.selectedIds.contains(item.id) ||
              _matchesQuestionResult(item, tabIndex),
        )
        .take(12)
        .toList(growable: false);
    return recommended;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 300;
        final gap = compact ? 4.0 : AppSpacing.sm;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '質問結果に合う候補を表示しています',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!compact)
                        Text(
                          '追加したい体験だけ選んでください。検索時は全件を対象にします。',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('おすすめ')),
                    ButtonSegment(value: true, label: Text('全件')),
                  ],
                  selected: {_showAll},
                  onSelectionChanged: (value) {
                    setState(() => _showAll = value.first);
                  },
                ),
              ],
            ),
            SizedBox(height: gap),
            SizedBox(
              height: compact ? 40 : 48,
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                labelPadding: EdgeInsets.zero,
                tabs: [
                  for (final tab in _tabs)
                    Tab(
                      height: compact ? 40 : 48,
                      icon: compact ? null : Icon(tab.icon, size: 20),
                      text: tab.label,
                    ),
                ],
              ),
            ),
            SizedBox(height: gap),
            SizedBox(
              height: compact ? 40 : 48,
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: '施設名・メニュー名を検索',
                  prefixIcon: const Icon(Icons.search),
                  prefixIconConstraints: compact
                      ? const BoxConstraints(minWidth: 40, minHeight: 40)
                      : null,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: compact
                      ? const EdgeInsets.symmetric(vertical: 8)
                      : null,
                ),
              ),
            ),
            SizedBox(height: gap),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  for (var index = 0; index < _tabs.length; index++)
                    _SpecificWishGrid(
                      items: _itemsFor(index),
                      selectedIds: widget.selectedIds,
                      onToggleItem: widget.onToggleItem,
                    ),
                ],
              ),
            ),
            SizedBox(height: gap),
            SizedBox(
              height: compact ? 38 : 44,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '具体的な希望 ${widget.selectedIds.length}件',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: widget.isApplying ? null : widget.onApply,
                    icon: widget.isApplying
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      widget.isApplying ? '反映中…' : '候補を作成',
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static const Set<WishItemCategory> _foodCategories = {
    WishItemCategory.specialDrink,
    WishItemCategory.cafeDrink,
    WishItemCategory.juice,
    WishItemCategory.soup,
    WishItemCategory.drinkJelly,
    WishItemCategory.food,
    WishItemCategory.dessert,
    WishItemCategory.snack,
  };
}

class _SpecificWishGrid extends StatefulWidget {
  const _SpecificWishGrid({
    required this.items,
    required this.selectedIds,
    required this.onToggleItem,
  });

  final List<WishItem> items;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleItem;

  @override
  State<_SpecificWishGrid> createState() => _SpecificWishGridState();
}

class _SpecificWishGridState extends State<_SpecificWishGrid> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _SpecificWishGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Center(
        child: Text(
          'このカテゴリに質問結果と一致する候補はありません。\n「全件」に切り替えると追加できます。',
          textAlign: TextAlign.center,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 3 : 2;
        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          trackVisibility: true,
          interactive: true,
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              mainAxisExtent: 70,
            ),
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final selected = widget.selectedIds.contains(item.id);
              return InkWell(
                onTap: () => widget.onToggleItem(item.id),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.add_circle_outline,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _GuidedProcessingOverlay extends StatelessWidget {
  const _GuidedProcessingOverlay();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface.withValues(alpha: 0.88),
      child: Center(
        child: Card(
          elevation: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'やりたいことを整理しています…',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '処理が完了し次第、すぐに一覧を表示します。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactWishList extends StatelessWidget {
  const _CompactWishList({required this.controller, required this.onContinue});

  final WishListController controller;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final items = controller.visibleItems;
    final groups = _groupItems(items);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '現在楽しめるもの ${items.length}件・選択 '
                  '${appState.selectedWishCount}件',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('候補確認へ'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: TextField(
            onChanged: controller.setQuery,
            decoration: const InputDecoration(
              labelText: '名前・店舗名を検索',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: groups.isEmpty
              ? const Center(child: Text('現在表示できる項目はありません。'))
              : Scrollbar(
                  thumbVisibility: true,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    children: [
                      for (final group in groups)
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                            initiallyExpanded: group.items.any(
                              (item) => appState.wishStateFor(item.id).selected,
                            ),
                            leading: Icon(group.icon),
                            title: Text(group.title),
                            subtitle: Text('${group.items.length}件'),
                            children: [
                              for (final item in group.items)
                                _WishItemRow(
                                  item: item,
                                  onShowDetails: () =>
                                      _showDetails(context, item),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  List<_WishGroup> _groupItems(List<WishItem> items) {
    final definitions = <_WishGroupDefinition>[
      const _WishGroupDefinition(
        title: '飲みたい',
        icon: Icons.local_drink_outlined,
        categories: {
          WishItemCategory.specialDrink,
          WishItemCategory.cafeDrink,
          WishItemCategory.juice,
          WishItemCategory.soup,
          WishItemCategory.drinkJelly,
        },
      ),
      const _WishGroupDefinition(
        title: '食べたい',
        icon: Icons.restaurant_outlined,
        categories: {
          WishItemCategory.food,
          WishItemCategory.snack,
          WishItemCategory.dessert,
        },
      ),
      const _WishGroupDefinition(
        title: '乗りたい',
        icon: Icons.attractions_outlined,
        categories: {WishItemCategory.attraction},
      ),
      const _WishGroupDefinition(
        title: '見たい',
        icon: Icons.theater_comedy_outlined,
        categories: {WishItemCategory.entertainment},
      ),
      const _WishGroupDefinition(
        title: '会いたい',
        icon: Icons.emoji_people_outlined,
        categories: {WishItemCategory.greeting},
      ),
      const _WishGroupDefinition(
        title: '買いたい・その他',
        icon: Icons.shopping_bag_outlined,
        categories: {
          WishItemCategory.goods,
          WishItemCategory.souvenir,
          WishItemCategory.photo,
          WishItemCategory.other,
        },
      ),
    ];

    return definitions
        .map(
          (definition) => _WishGroup(
            title: definition.title,
            icon: definition.icon,
            items: items
                .where((item) => definition.categories.contains(item.category))
                .toList(growable: false),
          ),
        )
        .where((group) => group.items.isNotEmpty)
        .toList(growable: false);
  }

  static String compactSubtitle(WishItem item) {
    final parts = <String>[];
    if (item.freeDrinkEligible) {
      parts.add('フリードリンク');
    }
    parts.add(
      item.venueNames.length == 1
          ? item.venueNames.first
          : '${item.venueNames.length}店舗',
    );
    return parts.join('・');
  }
}

class _WishItemRow extends StatelessWidget {
  const _WishItemRow({required this.item, required this.onShowDetails});

  final WishItem item;
  final VoidCallback onShowDetails;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final state = appState.wishStateFor(item.id);

    return CheckboxListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      value: state.selected,
      onChanged: (value) {
        appState.toggleWishSelected(item.id, value ?? false);
      },
      secondary: IconButton(
        tooltip: '詳細を表示',
        onPressed: onShowDetails,
        icon: const Icon(Icons.info_outline),
      ),
      title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        _CompactWishList.compactSubtitle(item),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _WishGroupDefinition {
  const _WishGroupDefinition({
    required this.title,
    required this.icon,
    required this.categories,
  });

  final String title;
  final IconData icon;
  final Set<WishItemCategory> categories;
}

class _WishGroup {
  const _WishGroup({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<WishItem> items;
}

void _showDetails(BuildContext context, WishItem item) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(item.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('販売：${item.venueNames.join('／')}'),
          Text(
            '期間：${item.startDate.month}/${item.startDate.day}'
            '～${item.endDate.month}/${item.endDate.day}',
          ),
          if (item.priceYen != null) Text('価格：¥${item.priceYen}'),
          if (item.description != null) ...[
            const SizedBox(height: 8),
            Text(item.description!),
          ],
          if (item.freeDrinkEligibilityNote != null) ...[
            const SizedBox(height: 8),
            Text(item.freeDrinkEligibilityNote!),
          ],
        ],
      ),
    ),
  );
}
