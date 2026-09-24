import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/dependency/service_locator.dart';
import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../domain/entities/wish_item.dart';
import '../../domain/entities/wish_item_state.dart';
import '../../domain/enums/wish_item_category.dart';
import '../../domain/enums/preferred_time.dart';
import '../../domain/enums/wait_tolerance.dart';
import '../../domain/enums/wish_importance.dart';
import 'guided_planning_controller.dart';
import 'wish_list_controller.dart';

class WishListScreen extends StatefulWidget {
  const WishListScreen({
    super.key,
    required this.onCandidateReviewPressed,
    required this.onSettingsPressed,
    required this.onFlowContinueAvailabilityChanged,
  });

  final VoidCallback onCandidateReviewPressed;
  final VoidCallback onSettingsPressed;
  final ValueChanged<bool> onFlowContinueAvailabilityChanged;

  @override
  State<WishListScreen> createState() => WishListScreenState();
}

class WishListScreenState extends State<WishListScreen> {
  WishListController? _wishController;
  GuidedPlanningController? _chatController;
  bool _showList = true;
  bool _isApplyingGuidedResult = false;
  bool _showGuidedProcessing = false;
  int _guidedApplyRequestId = 0;

  WishListController get wishController => _wishController!;
  GuidedPlanningController get chatController => _chatController!;

  void _notifyFlowContinueAvailability() {
    // 希望整理の完了だけでは候補確認へ進ませません。
    // 「候補を作成」で整理結果をWishへ反映し、一覧へ移動した後、
    // または利用者が一覧選択モードを明示的に開いた場合だけ有効化します。
    widget.onFlowContinueAvailabilityChanged(_showList);
  }

  void _onGuidedPlanningChanged() {
    _notifyFlowContinueAvailability();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = AppStateScope.of(context);
    _wishController ??= WishListController(
      appState: appState,
      facilityRepository: ServiceLocator.facilityRepository,
    )..load();
    if (_chatController == null) {
      _chatController = GuidedPlanningController(appState: appState)
        ..addListener(_onGuidedPlanningChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _notifyFlowContinueAvailability();
        }
      });
    }
  }

  @override
  void dispose() {
    _wishController?.dispose();
    _chatController?.removeListener(_onGuidedPlanningChanged);
    _chatController?.dispose();
    super.dispose();
  }

  Future<void> applyAndContinue() async {
    await wishController.applySelectedItemsToPlan();
    if (!mounted) {
      return;
    }
    // 成功は次画面への遷移で明確に分かるため、操作を遮る通知は表示しません。
    // エラーやユーザー対応が必要な通知だけを SnackBar に残します。
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
      await chatController.applyToWishListWithDynamicScoring(
        wishController.allItems,
      );
      if (!mounted || requestId != _guidedApplyRequestId) {
        return;
      }

      setState(() => _showList = true);
      // 候補作成が完了した時点で、下部の「プラン候補を確認」を有効化します。
      _notifyFlowContinueAvailability();
      // 候補一覧の表示自体を成功フィードバックとし、成功通知は重ねません。
    } finally {
      if (mounted && requestId == _guidedApplyRequestId) {
        setState(() {
          _isApplyingGuidedResult = false;
          _showGuidedProcessing = false;
        });
      }
    }
  }

  void _applyDebugPreset(GuidedPlanningDebugPreset preset) {
    chatController.applyDebugPreset(preset);
    setState(() => _showList = false);
    _notifyFlowContinueAvailability();

    // 回答チップの更新で適用状態が見えるため、デバッグ用の成功通知は表示しません。
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
      _showList = true;
    });
    _notifyFlowContinueAvailability();
    // リセット結果は画面状態で確認できるため、成功通知は表示しません。
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

        final hasPark = appState.tripSettings.parkId == 'tokyo_disneyland' ||
            appState.tripSettings.parkId == 'tokyo_disneysea';
        if (!hasPark) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onFlowContinueAvailabilityChanged(false);
            }
          });
          return _ParkRequiredView(onSettingsPressed: widget.onSettingsPressed);
        }

        return Column(
          children: [
            _ModeSwitcher(
              showList: _showList,
              onWizardPressed: () {
                setState(() => _showList = false);
                _notifyFlowContinueAvailability();
              },
              onListPressed: () {
                setState(() => _showList = true);
                _notifyFlowContinueAvailability();
              },
              onResetPressed: _resetWishSelection,
              onDebugPresetSelected:
                  kDebugMode ? _applyDebugPreset : null,
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _showList
                        ? _CompactWishList(
                            controller: wishController,
                          )
                        : _GuidedWizard(
                            controller: chatController,
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

class _ParkRequiredView extends StatelessWidget {
  const _ParkRequiredView({required this.onSettingsPressed});

  final VoidCallback onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, size: 42, color: colors.primary),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'まずパークを選んでください',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'ランドまたはシーを選ぶと、そのパークの施設や体験を選べます。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onSettingsPressed,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('旅行設定でパークを選ぶ'),
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

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({
    required this.showList,
    required this.onWizardPressed,
    required this.onListPressed,
    required this.onResetPressed,
    required this.onDebugPresetSelected,
  });

  final bool showList;
  final VoidCallback onWizardPressed;
  final VoidCallback onListPressed;
  final VoidCallback onResetPressed;
  final ValueChanged<GuidedPlanningDebugPreset>?
      onDebugPresetSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final wizardButton = showList
              ? OutlinedButton.icon(
                  onPressed: onWizardPressed,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('希望整理（任意）'),
                )
              : FilledButton.tonalIcon(
                  onPressed: onWizardPressed,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('希望整理（任意）'),
                );
          final listButton = showList
              ? FilledButton.tonalIcon(
                  onPressed: onListPressed,
                  icon: const Icon(Icons.checklist),
                  label: const Text('一覧から選ぶ'),
                )
              : OutlinedButton.icon(
                  onPressed: onListPressed,
                  icon: const Icon(Icons.checklist_outlined),
                  label: const Text('一覧から選ぶ'),
                );

          if (compact) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: wizardButton),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: listButton),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onResetPressed,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('回答と選択をリセット'),
                  ),
                ),
                if (onDebugPresetSelected != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    width: double.infinity,
                    child: _DebugPresetMenu(
                      onSelected: onDebugPresetSelected!,
                      expanded: true,
                    ),
                  ),
                ],
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: wizardButton),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: listButton),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: onResetPressed,
                icon: const Icon(Icons.restart_alt),
                label: const Text('リセット'),
              ),
              if (onDebugPresetSelected != null) ...[
                const SizedBox(width: AppSpacing.sm),
                _DebugPresetMenu(
                  onSelected: onDebugPresetSelected!,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DebugPresetMenu extends StatelessWidget {
  const _DebugPresetMenu({
    required this.onSelected,
    this.expanded = false,
  });

  final ValueChanged<GuidedPlanningDebugPreset> onSelected;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = PopupMenuButton<GuidedPlanningDebugPreset>(
      tooltip: 'デバッグ回答を適用',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final preset in GuidedPlanningDebugPreset.values)
          PopupMenuItem(
            value: preset,
            child: Row(
              children: [
                const Icon(Icons.bug_report_outlined, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Text(preset.label),
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bug_report_outlined, size: 18),
            SizedBox(width: AppSpacing.sm),
            Text('デバッグ回答'),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );

    if (!expanded) {
      return button;
    }

    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: double.infinity,
        child: button,
      ),
    );
  }
}

class _GuidedWizard extends StatelessWidget {
  const _GuidedWizard({
    required this.controller,
    required this.isApplying,
    required this.onApply,
  });

  final GuidedPlanningController controller;
  final bool isApplying;
  final Future<void> Function() onApply;

  @override
  Widget build(BuildContext context) {
    final completed = controller.step == GuidedPlanningStep.completed;
    final welcome = controller.step == GuidedPlanningStep.welcome;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520 || constraints.maxHeight < 470;
        final desktopCompleted = completed && constraints.maxWidth >= 900;
        final outerPadding = desktopCompleted
            ? AppSpacing.sm
            : compact
            ? AppSpacing.sm
            : AppSpacing.md;
        final horizontalPadding = desktopCompleted
            ? AppSpacing.md
            : compact
            ? AppSpacing.sm
            : AppSpacing.lg;
        final verticalPadding = desktopCompleted
            ? AppSpacing.sm
            : compact
            ? AppSpacing.sm
            : AppSpacing.md;

        if (constraints.maxWidth < 520 && !welcome && !completed) {
          return _MobileGuidedQuestionPage(
            key: ValueKey(controller.step),
            controller: controller,
          );
        }

        return Padding(
          padding: EdgeInsets.all(outerPadding),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: desktopCompleted ? 1180 : 980,
              ),
              child: Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
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
                  if (!welcome && !desktopCompleted) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _GuidedStepIndicator(
                      currentStep: controller.currentStepNumber,
                      totalSteps: controller.totalStepCount,
                      completed: completed,
                    ),
                  ],
                  if (completed) ...[
                    SizedBox(
                      height: desktopCompleted ? AppSpacing.xs : AppSpacing.sm,
                    ),
                    _CompletedWishSummary(controller: controller),
                    SizedBox(
                      height: desktopCompleted ? AppSpacing.xs : AppSpacing.sm,
                    ),
                  ] else if (!welcome) ...[
                    SizedBox(height: compact ? AppSpacing.xs : AppSpacing.md),
                    Icon(
                      _stepIcon(controller.step),
                      size: compact ? 24 : 30,
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
                    const SizedBox(height: AppSpacing.xs),
                    _AiGuidanceNote(message: controller.aiNote),
                    const SizedBox(height: AppSpacing.sm),
                  ] else
                    SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
                  Expanded(
                    child: completed
                        ? _GuidedCompletionCard(
                            isApplying: isApplying,
                            onApply: onApply,
                          )
                        : _QuestionOptions(
                            key: ValueKey(controller.step),
                            controller: controller,
                          ),
                  ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _stepIcon(GuidedPlanningStep step) => switch (step) {
    GuidedPlanningStep.welcome => Icons.waving_hand_outlined,
    GuidedPlanningStep.mainFocus => Icons.auto_awesome_outlined,
    GuidedPlanningStep.focusDetail => Icons.tune_rounded,
    GuidedPlanningStep.secondaryExperience => Icons.compare_arrows_rounded,
    GuidedPlanningStep.foodStyle => Icons.restaurant_menu_outlined,
    GuidedPlanningStep.freeDrinkPreference => Icons.local_drink_outlined,
    GuidedPlanningStep.characterInterest => Icons.face_outlined,
    GuidedPlanningStep.seasonalPreference => Icons.celebration_outlined,
    GuidedPlanningStep.completed => Icons.check_circle_outline,
  };
}



class _MobileGuidedQuestionPage extends StatefulWidget {
  const _MobileGuidedQuestionPage({
    super.key,
    required this.controller,
  });

  final GuidedPlanningController controller;

  @override
  State<_MobileGuidedQuestionPage> createState() =>
      _MobileGuidedQuestionPageState();
}

class _MobileGuidedQuestionPageState
    extends State<_MobileGuidedQuestionPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _MobileGuidedQuestionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.step != widget.controller.step) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          trackVisibility: true,
          interactive: true,
          child: ListView(
            controller: _scrollController,
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '前の質問へ戻る',
                    onPressed: controller.goBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Text(
                    'ステップ ${controller.currentStepNumber} / ${controller.totalStepCount}',
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
                value: controller.currentStepNumber / controller.totalStepCount,
              ),
              const SizedBox(height: AppSpacing.xs),
              _GuidedStepIndicator(
                currentStep: controller.currentStepNumber,
                totalSteps: controller.totalStepCount,
                completed: false,
              ),
              const SizedBox(height: AppSpacing.sm),
              Icon(
                _mobileStepIcon(controller.step),
                size: 24,
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
              const SizedBox(height: AppSpacing.xs),
              _AiGuidanceNote(message: controller.aiNote),
              const SizedBox(height: AppSpacing.sm),
              for (final option in controller.options) ...[
                SizedBox(
                  height: 82,
                  child: _OptionTile(
                    label: option,
                    description: controller.optionDescription(option),
                    icon: controller.optionIcon(option),
                    selected: controller.isMultiSelectStep &&
                        controller.isOptionSelected(option),
                    onTap: () => controller.answer(option),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (controller.isMultiSelectStep)
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: controller.confirmCurrentMultiSelection,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('選択内容を確定して次へ'),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _mobileStepIcon(GuidedPlanningStep step) => switch (step) {
    GuidedPlanningStep.welcome => Icons.waving_hand_outlined,
    GuidedPlanningStep.mainFocus => Icons.auto_awesome_outlined,
    GuidedPlanningStep.focusDetail => Icons.tune_rounded,
    GuidedPlanningStep.secondaryExperience => Icons.compare_arrows_rounded,
    GuidedPlanningStep.foodStyle => Icons.restaurant_menu_outlined,
    GuidedPlanningStep.freeDrinkPreference => Icons.local_drink_outlined,
    GuidedPlanningStep.characterInterest => Icons.face_outlined,
    GuidedPlanningStep.seasonalPreference => Icons.celebration_outlined,
    GuidedPlanningStep.completed => Icons.check_circle_outline,
  };
}

class _GuidedStepIndicator extends StatelessWidget {
  const _GuidedStepIndicator({
    required this.currentStep,
    required this.totalSteps,
    required this.completed,
  });

  final int currentStep;
  final int totalSteps;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    const labels = ['開始', '目的', '季節', '飲食', '体験', '確認'];
    final visible = labels.take(totalSteps.clamp(1, labels.length)).toList();

    return Row(
      children: [
        for (var index = 0; index < visible.length; index++) ...[
          Expanded(
            child: Column(
              children: [
                Icon(
                  completed || index + 1 < currentStep
                      ? Icons.check_circle
                      : index + 1 == currentStep
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: index + 1 <= currentStep || completed
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 2),
                Text(
                  visible[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: index + 1 <= currentStep || completed
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (index != visible.length - 1)
            SizedBox(
              width: 14,
              child: Divider(
                color: index + 1 < currentStep || completed
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
        ],
      ],
    );
  }
}

class _AiGuidanceNote extends StatelessWidget {
  const _AiGuidanceNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 17, color: colors.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeStartCard extends StatelessWidget {
  const _WelcomeStartCard({required this.controller});

  final GuidedPlanningController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            MediaQuery.sizeOf(context).width < 520 ||
            constraints.maxHeight < 210;

        if (compact) {
          return Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primaryContainer.withValues(alpha: 0.72),
                    colors.secondaryContainer.withValues(alpha: 0.52),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 21,
                        color: colors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          '希望をもう少し整理する',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '希望を順番に整理します・後から変更できます',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: FilledButton.icon(
                      onPressed: () => controller.answer('希望整理を始める'),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('希望整理を始める'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primaryContainer.withValues(alpha: 0.72),
                    colors.secondaryContainer.withValues(alpha: 0.52),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 38,
                    color: colors.primary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '希望をもう少し整理する',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '施設名に詳しくなくても、好みを選ぶだけで候補を整理できます。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _WelcomeBenefit(
                        icon: Icons.schedule,
                        label: '約1〜2分',
                      ),
                      _WelcomeBenefit(
                        icon: Icons.edit_outlined,
                        label: '後から変更可能',
                      ),
                      _WelcomeBenefit(
                        icon: Icons.auto_fix_high,
                        label: '候補を自動整理',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () => controller.answer('希望整理を始める'),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('希望整理を始める'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WelcomeBenefit extends StatelessWidget {
  const _WelcomeBenefit({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionOptions extends StatefulWidget {
  const _QuestionOptions({
    super.key,
    required this.controller,
  });

  final GuidedPlanningController controller;

  @override
  State<_QuestionOptions> createState() => _QuestionOptionsState();
}

class _QuestionOptionsState extends State<_QuestionOptions> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _QuestionOptions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.step != widget.controller.step &&
        _scrollController.hasClients) {
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
    final controller = widget.controller;
    if (controller.step == GuidedPlanningStep.welcome) {
      return _WelcomeStartCard(controller: controller);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 480
            ? 2
            : 1;
        final optionCount = controller.options.length;
        final compactHeight = constraints.maxHeight < 260;
        final tileHeight = compactHeight ? 76.0 : 88.0;

        return Column(
          children: [
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                trackVisibility: true,
                interactive: true,
                child: GridView.builder(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final colors = Theme.of(context).colorScheme;

        if (compact) {
          return Container(
            height: 58,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: colors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '回答',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: items.isEmpty
                      ? Text(
                          '選択なし',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (var index = 0; index < items.length; index++) ...[
                                if (index > 0) const SizedBox(width: 6),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  avatar: const Icon(Icons.check, size: 14),
                                  label: Text(items[index]),
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 20,
                color: colors.primary,
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
      },
    );
  }
}

class _GuidedCompletionCard extends StatelessWidget {
  const _GuidedCompletionCard({
    required this.isApplying,
    required this.onApply,
  });

  final bool isApplying;
  final Future<void> Function() onApply;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            MediaQuery.sizeOf(context).width < 520 ||
            constraints.maxHeight < 220;

        if (compact) {
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isApplying ? null : onApply,
                icon: isApplying
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  isApplying ? '候補を整理中…' : 'この内容で候補を整理',
                ),
              ),
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 36,
                      color: colors.primary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '回答内容から候補を整理します',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '次の候補確認画面で、施設の追加・削除・'
                      '優先度変更ができます。',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isApplying ? null : onApply,
                        icon: isApplying
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(
                          isApplying
                              ? '候補を整理中…'
                              : 'この内容で候補を整理',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

class _CompactWishList extends StatefulWidget {
  const _CompactWishList({required this.controller});

  final WishListController controller;

  @override
  State<_CompactWishList> createState() => _CompactWishListState();
}

class _CompactWishListState extends State<_CompactWishList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final controller = widget.controller;
    final items = controller.visibleItems;
    final showFreeDrink =
        appState.tripSettings.usesVacationPackage &&
        appState.tripSettings.usesFreeDrinkBenefit;
    final groups = _groupItems(items, showFreeDrink: showFreeDrink);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '現在楽しめるもの ${items.length}件・選択 '
                  '${appState.selectedWishCount}件・候補枠 '
                  '${controller.selectedCandidateOptionCount}件',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (controller.selectedCandidateOptionCount >
            controller.selectedDistinctFacilityCandidateCount)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '複数メニューで同じ店舗を利用できる場合も、販売店舗はすべて候補に保持します。'
                '候補確認では同一店舗をまとめて表示します。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('すべて'),
                  selected: controller.categoryFilter == null,
                  onSelected: (_) => controller.setCategory(null),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('乗りたい'),
                  selected: controller.categoryFilter == WishItemCategory.attraction,
                  onSelected: (_) => controller.setCategory(WishItemCategory.attraction),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('ショー・パレード'),
                  selected: controller.categoryFilter == WishItemCategory.entertainment,
                  onSelected: (_) => controller.setCategory(WishItemCategory.entertainment),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('会いたい'),
                  selected: controller.categoryFilter == WishItemCategory.greeting,
                  onSelected: (_) => controller.setCategory(WishItemCategory.greeting),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('レストラン'),
                  selected: controller.categoryFilter == WishItemCategory.restaurant,
                  onSelected: (_) => controller.setCategory(WishItemCategory.restaurant),
                ),
                const SizedBox(width: 10),
                FilterChip(
                  label: const Text('選択済みのみ'),
                  selected: controller.selectedOnly,
                  onSelected: controller.setSelectedOnly,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: groups.isEmpty
              ? const Center(child: Text('現在表示できる項目はありません。'))
              : Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  interactive: true,
                  child: ListView(
                    controller: _scrollController,
                    primary: false,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    children: [
                      for (final group in groups)
                        Builder(
                          builder: (context) {
                            final selectedCount = group.items
                                .where(
                                  (item) =>
                                      appState.wishStateFor(item.id).selected,
                                )
                                .length;

                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: ExpansionTile(
                                initiallyExpanded: selectedCount > 0,
                                leading: Icon(group.icon),
                                title: Row(
                                  children: [
                                    Expanded(child: Text(group.title)),
                                    if (selectedCount > 0)
                                      _ClearWishGroupButton(
                                        selectedCount: selectedCount,
                                        onPressed: () {
                                          for (final item in group.items) {
                                            if (appState
                                                .wishStateFor(item.id)
                                                .selected) {
                                              appState.toggleWishSelected(
                                                item.id,
                                                false,
                                              );
                                            }
                                          }
                                        },
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  selectedCount == 0
                                      ? '${group.items.length}件'
                                      : '${group.items.length}件・選択 $selectedCount件',
                                ),
                                children: [
                                  for (final item in group.items)
                                    _WishItemRow(
                                      item: item,
                                      repeatable: controller.supportsRepeatCount(item),
                                      onShowDetails: () =>
                                          _showDetails(context, item),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  List<_WishGroup> _groupItems(
    List<WishItem> items, {
    required bool showFreeDrink,
  }) {
    final definitions = <_WishGroupDefinition>[
      if (showFreeDrink)
        const _WishGroupDefinition(
          title: 'フリードリンク',
          icon: Icons.card_giftcard_outlined,
          categories: {},
          freeDrinkOnly: true,
        ),
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
        title: 'パーク内レストラン',
        icon: Icons.restaurant_menu_outlined,
        categories: {WishItemCategory.restaurant},
      ),
      const _WishGroupDefinition(
        title: 'ホテルレストラン',
        icon: Icons.hotel_outlined,
        categories: {WishItemCategory.hotelRestaurant},
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
            items: items.where((item) {
              if (definition.freeDrinkOnly) {
                return item.freeDrinkEligible;
              }
              if (showFreeDrink && item.freeDrinkEligible) {
                return false;
              }
              return definition.categories.contains(item.category);
            }).toList(growable: false),
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
          : '${item.venueNames.length}店舗から最適なお店を選びます',
    );
    return parts.join('・');
  }
}

class _ClearWishGroupButton extends StatelessWidget {
  const _ClearWishGroupButton({
    required this.selectedCount,
    required this.onPressed,
  });

  final int selectedCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 520;

    if (compact) {
      return Tooltip(
        message: 'このカテゴリの選択をすべて解除',
        child: IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: '一括解除',
          onPressed: onPressed,
          icon: const Icon(Icons.remove_done_outlined),
        ),
      );
    }

    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.remove_done_outlined, size: 18),
      label: Text('$selectedCount件を一括解除'),
    );
  }
}

class _WishItemRow extends StatelessWidget {
  const _WishItemRow({
    required this.item,
    required this.repeatable,
    required this.onShowDetails,
  });

  final WishItem item;
  final bool repeatable;
  final VoidCallback onShowDetails;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final state = appState.wishStateFor(item.id);
    final importance = state.importance;
    final isMust = importance == WishImportance.mustDo;
    final isOptional = importance == WishImportance.optional;

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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _CompactWishListState.compactSubtitle(item),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (state.selected) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    isMust ? Icons.star : Icons.star_border,
                    size: 16,
                  ),
                  label: const Text('絶対行きたい'),
                  selected: isMust,
                  onSelected: (selected) => appState.updateWishImportance(
                    item.id,
                    selected ? WishImportance.mustDo : WishImportance.optional,
                  ),
                ),
                FilterChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
                  label: const Text('できれば'),
                  selected: isOptional,
                  onSelected: (selected) => appState.updateWishImportance(
                    item.id,
                    selected ? WishImportance.optional : WishImportance.normal,
                  ),
                ),
                if (repeatable)
                  _WishRepeatCountControl(
                    count: state.targetCount,
                    onChanged: (count) =>
                        appState.updateWishTargetCount(item.id, count),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.tune, size: 16),
                  label: Text(_wishConditionLabel(state)),
                  onPressed: () => _showWishConditions(context, item.id),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WishRepeatCountControl extends StatelessWidget {
  const _WishRepeatCountControl({required this.count, required this.onChanged});

  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '希望回数を減らす',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
            onPressed: count > 1 ? () => onChanged(count - 1) : null,
            icon: const Icon(Icons.remove, size: 16),
          ),
          Text('$count回', style: Theme.of(context).textTheme.labelMedium),
          IconButton(
            tooltip: '希望回数を増やす',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
            onPressed: count < 5 ? () => onChanged(count + 1) : null,
            icon: const Icon(Icons.add, size: 16),
          ),
        ],
      ),
    );
  }
}

class _WishGroupDefinition {
  const _WishGroupDefinition({
    required this.title,
    required this.icon,
    required this.categories,
    this.freeDrinkOnly = false,
  });

  final String title;
  final IconData icon;
  final Set<WishItemCategory> categories;
  final bool freeDrinkOnly;
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


String _wishConditionLabel(WishItemState state) {
  final parts = <String>[];
  if (state.preferredTime != PreferredTime.anytime) {
    parts.add(state.preferredTime.label);
  }
  final maxWait = state.waitTolerance.maxMinutes;
  if (maxWait != null) {
    parts.add('待ち$maxWait分まで');
  }
  return parts.isEmpty ? '詳細条件' : parts.join('・');
}


Future<void> _showWishConditions(BuildContext context, String itemId) async {
  final appState = AppStateScope.of(context);
  var preferredTime = appState.wishStateFor(itemId).preferredTime;
  var waitTolerance = appState.wishStateFor(itemId).waitTolerance;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('詳細条件（任意）', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text('設定しなくてもプランは作れます。必要な希望だけ指定してください。'),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<PreferredTime>(
                initialValue: preferredTime,
                decoration: const InputDecoration(labelText: '希望時間帯', border: OutlineInputBorder()),
                items: PreferredTime.values.map((value) => DropdownMenuItem(value: value, child: Text(value.label))).toList(),
                onChanged: (value) { if (value != null) setSheetState(() => preferredTime = value); },
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<WaitTolerance>(
                initialValue: waitTolerance,
                decoration: const InputDecoration(labelText: '待ち時間の目安', helperText: '「できれば」と組み合わせると、予想待ち時間が目安以内の時だけ候補に残します。\n'
                    '通常・絶対行きたいでは、目安を超えても希望自体は残します。', border: OutlineInputBorder()),
                items: WaitTolerance.values.map((value) => DropdownMenuItem(value: value, child: Text(value.label))).toList(),
                onChanged: (value) { if (value != null) setSheetState(() => waitTolerance = value); },
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  appState.updateWishPreferredTime(itemId, preferredTime);
                  appState.updateWishWaitTolerance(itemId, waitTolerance);
                  Navigator.of(sheetContext).pop();
                },
                child: const Text('この条件を使う'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
