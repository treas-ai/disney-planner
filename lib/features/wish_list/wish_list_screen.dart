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

  void _applyChatResult() {
    final selected = chatController.applyToWishList(wishController.allItems);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$selected件をやりたいことへ追加しました。')));
    setState(() => _showList = true);
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
            ),
            Expanded(
              child: _showList
                  ? _CompactWishList(
                      controller: wishController,
                      onContinue: _applyAndContinue,
                    )
                  : _GuidedWizard(
                      controller: chatController,
                      onApply: _applyChatResult,
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
  });

  final bool showList;
  final VoidCallback onWizardPressed;
  final VoidCallback onListPressed;

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
        ],
      ),
    );
  }
}

class _GuidedWizard extends StatelessWidget {
  const _GuidedWizard({required this.controller, required this.onApply});

  final GuidedPlanningController controller;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final completed = controller.step == GuidedPlanningStep.completed;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
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
                        onPressed: controller.restart,
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: const Text('最初から'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  LinearProgressIndicator(
                    value:
                        controller.currentStepNumber /
                        controller.totalStepCount,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Icon(
                    _stepIcon(controller.step),
                    size: 42,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    completed ? controller.summary : controller.question,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!completed) ...[
                    const SizedBox(height: 4),
                    Text(
                      controller.selectionGuide,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: completed
                        ? _CompletionActions(onApply: onApply)
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
    GuidedPlanningStep.vacationPackage => Icons.card_travel_outlined,
    GuidedPlanningStep.freeDrink => Icons.local_drink_outlined,
    GuidedPlanningStep.foodInterests => Icons.restaurant_menu_outlined,
    GuidedPlanningStep.entertainment => Icons.attractions_outlined,
    GuidedPlanningStep.completed => Icons.check_circle_outline,
  };
}

class _QuestionOptions extends StatefulWidget {
  const _QuestionOptions({required this.controller});
  final GuidedPlanningController controller;

  @override
  State<_QuestionOptions> createState() => _QuestionOptionsState();
}

class _QuestionOptionsState extends State<_QuestionOptions> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 2 : 1;
        final optionCount = controller.options.length;
        final rows = (optionCount / columns).ceil();
        final desiredHeight = rows * 60.0 + (rows - 1) * 8.0;
        final needsScroll =
            desiredHeight >
            constraints.maxHeight - (controller.isFoodStep ? 64 : 0);

        final grid = GridView.builder(
          controller: _scrollController,
          physics: needsScroll
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            mainAxisExtent: 60,
          ),
          itemCount: optionCount,
          itemBuilder: (context, index) {
            final option = controller.options[index];
            return _OptionTile(
              label: option,
              selected:
                  controller.isFoodStep && controller.isOptionSelected(option),
              onTap: () => controller.answer(option),
            );
          },
        );

        return Column(
          children: [
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: needsScroll,
                trackVisibility: needsScroll,
                child: grid,
              ),
            ),
            if (controller.isFoodStep) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: controller.confirmFoodSelection,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('次へ'),
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
    required this.selected,
    required this.onTap,
  });

  final String label;
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionActions extends StatelessWidget {
  const _CompletionActions({required this.onApply});

  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onApply,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('やりたいことへ反映して確認'),
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
    final items = controller.allItems
        .where((item) => item.parkId == appState.tripSettings.parkId)
        .toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '選択 ${appState.selectedWishCount}件',
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
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final state = appState.wishStateFor(item.id);

              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: state.selected,
                onChanged: (value) {
                  appState.toggleWishSelected(item.id, value ?? false);
                },
                secondary: IconButton(
                  tooltip: '詳細を表示',
                  onPressed: () => _showDetails(context, item),
                  icon: Icon(_iconFor(item.category)),
                ),
                title: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _compactSubtitle(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _compactSubtitle(WishItem item) {
    final parts = <String>[item.category.label];
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

  IconData _iconFor(WishItemCategory category) {
    return switch (category) {
      WishItemCategory.specialDrink => Icons.local_drink_outlined,
      WishItemCategory.cafeDrink => Icons.coffee_outlined,
      WishItemCategory.juice => Icons.local_cafe_outlined,
      WishItemCategory.soup => Icons.soup_kitchen_outlined,
      WishItemCategory.drinkJelly => Icons.bubble_chart_outlined,
      WishItemCategory.food || WishItemCategory.snack => Icons.lunch_dining,
      WishItemCategory.dessert => Icons.cake_outlined,
      WishItemCategory.entertainment => Icons.theater_comedy_outlined,
      WishItemCategory.attraction => Icons.attractions_outlined,
      _ => Icons.favorite_border,
    };
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
}
