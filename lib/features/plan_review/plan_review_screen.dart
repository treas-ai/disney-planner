import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../domain/entities/day_schedule.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/plan_preference.dart';
import '../../domain/entities/plan_coverage_advice.dart';
import '../../domain/entities/schedule_item.dart';
import '../../domain/entities/schedule_validation_issue.dart';
import '../../domain/entities/trip_settings.dart';
import '../../domain/services/plan_text_exporter.dart';
import '../../domain/enums/facility_access_method.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/enums/lottery_fallback_action.dart';
import '../../domain/enums/fixed_time_status.dart';
import '../../domain/enums/schedule_validation_severity.dart';
import '../facility/widgets/facility_visual_style.dart';
import '../facility/widgets/fixed_schedule_editor_sheet.dart';
import 'schedule_controller.dart';

class PlanReviewScreen extends StatefulWidget {
  const PlanReviewScreen({super.key, this.onContinueToToday});

  final VoidCallback? onContinueToToday;

  @override
  State<PlanReviewScreen> createState() {
    return _PlanReviewScreenState();
  }
}

class _PlanReviewScreenState extends State<PlanReviewScreen> {
  ScheduleController? _controller;

  late final ScrollController _mobileScrollController;
  late final ScrollController _timelineScrollController;

  @override
  void initState() {
    super.initState();

    _mobileScrollController = ScrollController();
    _timelineScrollController = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_controller != null) {
      return;
    }

    final appState = AppStateScope.of(context);

    _controller = ScheduleController(appState);
    _controller!.addListener(_refresh);
  }

  @override
  void dispose() {
    _controller?.removeListener(_refresh);
    _controller?.dispose();
    _mobileScrollController.dispose();
    _timelineScrollController.dispose();

    super.dispose();
  }

  void _refresh() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _generateSchedule() async {
    final controller = _controller;

    if (controller == null) {
      return;
    }

    final appState = AppStateScope.of(context);
    // Generation before wish finalization is always a provisional
    // wait-time-first whole-day rebuild. The four final optimization modes are
    // shown only from "やりたいことはこれで決定".
    const selectedMode = ScheduleOptimizationMode.minimumWait;
    if (selectedMode != appState.tripSettings.scheduleOptimizationMode) {
      appState.updateTripSettings(
        appState.tripSettings.copyWith(scheduleOptimizationMode: selectedMode),
      );
    }

    await controller.generateSchedule(preserveManualFixedItems: false);

    if (!mounted ||
        controller.errorMessage != null ||
        controller.schedule == null) {
      return;
    }

    final targetController = MediaQuery.sizeOf(context).width >= 900
        ? _timelineScrollController
        : _mobileScrollController;

    if (!targetController.hasClients) {
      return;
    }

    await targetController.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finalizeWishesAndOptimize() async {
    final controller = _controller;
    if (controller == null || controller.schedule == null) return;
    final appState = AppStateScope.of(context);
    final selectedMode = await _showOptimizationModeDialog(
      appState.tripSettings.scheduleOptimizationMode,
      finalizingWishes: true,
    );
    if (!mounted || selectedMode == null) return;
    if (selectedMode != appState.tripSettings.scheduleOptimizationMode) {
      appState.updateTripSettings(
        appState.tripSettings.copyWith(scheduleOptimizationMode: selectedMode),
      );
    }
    await controller.generateSchedule(preserveManualFixedItems: false);
  }

  Future<ScheduleOptimizationMode?> _showOptimizationModeDialog(
    ScheduleOptimizationMode initialMode, {
    bool finalizingWishes = false,
  }) {
    var selectedMode = initialMode;
    return showDialog<ScheduleOptimizationMode>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(finalizingWishes ? '最終プランの組み方を選ぶ' : 'プランの組み方を選ぶ'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ScheduleOptimizationMode.values.map((mode) {
                final isSelected = mode == selectedMode;
                return ListTile(
                  onTap: () => setDialogState(() => selectedMode = mode),
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(_optimizationModeLabel(mode)),
                  subtitle: Text(_optimizationModeDescription(mode)),
                  contentPadding: EdgeInsets.zero,
                );
              }).toList(growable: false),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(selectedMode),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(finalizingWishes ? 'この組み方で最終プランを作る' : 'この組み方で作る'),
            ),
          ],
        ),
      ),
    );
  }

  String _optimizationModeLabel(ScheduleOptimizationMode mode) => switch (mode) {
        ScheduleOptimizationMode.balanced => 'バランス重視',
        ScheduleOptimizationMode.minimumWait => '待ち時間重視',
        ScheduleOptimizationMode.minimumWalking => '移動少なめ',
        ScheduleOptimizationMode.compactSchedule => 'まとまった自由時間',
      };

  String _optimizationModeDescription(ScheduleOptimizationMode mode) => switch (mode) {
        ScheduleOptimizationMode.balanced =>
          '待ち時間・移動・細切れの空白を総合して組みます。',
        ScheduleOptimizationMode.minimumWait =>
          '待ち時間を強く優先しつつ、極端な移動や細切れ空白は避けます。',
        ScheduleOptimizationMode.minimumWalking =>
          '同じエリアをまとめ、歩く負担を抑える組み方を優先します。',
        ScheduleOptimizationMode.compactSchedule =>
          '短い空白を減らし、追加予定を入れやすいまとまった自由時間を残します。',
      };

  Future<void> _removeOptionalAddition(Facility facility) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.removeOptionalAddition(facility.id);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${facility.name}を追加候補から削除し、残りの候補でプランを組み直しました。')),
    );
  }

  String _buildDebugOptimizationTrace(ScheduleController controller) {
    final required = controller.requiredFacilitiesForCurrentPark;
    final optional = controller.optionalAdditionsForCurrentPark;
    final adopted = controller.scheduledOptionalAdditions;
    final rejected = controller.unscheduledOptionalAdditions;
    final scheduledIds = controller.schedule?.items
            .map((item) => item.facilityId)
            .whereType<String>()
            .toList(growable: false) ??
        const <String>[];
    final requiredScheduled = required
        .where((facility) => scheduledIds.contains(facility.id))
        .length;
    final buffer = StringBuffer();
    buffer.writeln();
    buffer.writeln('【DEBUG: 追加候補・全日再最適化の内部判定】');
    buffer.writeln('DEBUG実装識別：v7.5.22 quality-gate-r3');
    buffer.writeln('この節はデバッグビルド専用です。通常利用者向けの説明ではありません。');
    buffer.writeln('主軸（やりたいこと）：$requiredScheduled/${required.length}件をスケジュール内で確認');
    buffer.writeln('追加候補：${adopted.length}/${optional.length}件採用、${rejected.length}件見送り');
    buffer.writeln('探索ルール：現在の主軸${required.length}件の維持を優先し、追加候補は採用数が最大になる組み合わせを大きい組み合わせから探索します。各試行では主軸と選択中の追加候補を同列にして全日再最適化します。');
    buffer.writeln('採用ガード：主軸が1件でも外れる、または試した追加候補が実際のスケジュールに入らない結果は不採用です。成立した最大件数の組み合わせを採用します。');
    buffer.writeln('注意：画面上に2時間などの自由時間があっても、その2時間の好きな位置にショーを置けるわけではありません。ショーは実際の公演開始時刻へ固定され、その前後の移動も必要です。');
    buffer.writeln('そのため自由時間が十分に見えても、公演時刻へ合わせて一日全体を並べ替えた結果、元のやりたいことが1件でも外れる場合は見送ります。以下の探索履歴で、実際に外れた主軸と追加候補の配置時刻を確認できます。');
    if (optional.isEmpty) {
      buffer.writeln('追加候補はありません。');
    } else {
      buffer.writeln('追加候補の個別結果：');
      for (final facility in optional) {
        final isAdopted = adopted.any((item) => item.id == facility.id);
        buffer.writeln('・${facility.name}');
        buffer.writeln('  状態：${isAdopted ? '採用・スケジュール内' : '今回は見送り・候補として保持'}');
        buffer.writeln('  主軸扱い：いいえ（削除しても元の「やりたいこと」には影響しません）');
        buffer.writeln('  削除可能：はい（追加候補カードから個別削除）');
        if (!isAdopted) {
          final reason = controller.optionalRejectionReason(facility.id);
          buffer.writeln('  現在確認できる理由：${reason ?? '主軸を100%維持する採用結果として確定できなかったため。'}');
        }
      }
    }
    buffer.writeln('組み合わせ探索試行数：${controller.optionalOptimizationTrialCount}回');
    buffer.writeln('最大採用探索結果：${controller.optionalOptimizationAdoptedCount}/${optional.length}件');
    if (controller.optionalOptimizationTrace.isNotEmpty) {
      buffer.writeln('探索履歴：');
      for (final line in controller.optionalOptimizationTrace) {
        buffer.writeln('  ・$line');
      }
    }
    buffer.writeln('現在の判定単位：各組み合わせごとに全日再生成し、主軸の施設ID/必要回数と、その試行で選んだ追加候補がすべて実スケジュールへ入ったかを検査します。');
    return buffer.toString();
  }

  Future<void> _showPlanTextExport() async {
    final controller = _controller;
    final schedule = controller?.schedule;

    if (controller == null || schedule == null) {
      return;
    }

    final appState = AppStateScope.of(context);
    const exporter = PlanTextExporter();

    final simpleText = exporter.export(
      schedule: schedule,
      settings: appState.tripSettings,
      parkName: controller.selectedParkName,
      preferences: controller.preferencesForExport,
      validationIssues: controller.validationIssues,
      format: PlanTextExportFormat.simple,
      todayAccessResults: appState.todayAccessResults,
    );
    var evaluationText = exporter.export(
      schedule: schedule,
      settings: appState.tripSettings,
      parkName: controller.selectedParkName,
      preferences: controller.preferencesForExport,
      validationIssues: controller.validationIssues,
      format: PlanTextExportFormat.evaluation,
      todayAccessResults: appState.todayAccessResults,
      coverageAdvice: controller.coverageAdvice,
    );
    final audit = controller.planQualityAudit;
    if (audit != null) {
      evaluationText += '\n【プラン品質Gate】\n';
      evaluationText += '最適化モード：${_optimizationModeLabel(appState.tripSettings.scheduleOptimizationMode)}\n';
      evaluationText += '総待ち時間：${audit.totalWaitMinutes}分\n';
      evaluationText += '総自由時間：${audit.totalFreeMinutes}分\n';
      evaluationText += '自由時間ブロック数：${audit.freeBlockCount}個\n';
      evaluationText += '最大連続自由時間：${audit.largestFreeBlockMinutes}分\n';
      evaluationText += '30分未満の自由時間：${audit.smallFreeBlockCount}個\n';
      evaluationText += '総推定移動時間：${audit.totalMovementMinutes}分\n';
      evaluationText += 'エリア跨ぎ回数：${audit.areaCrossingCount}回\n';
      evaluationText += '同一エリア再訪回数：${audit.areaRevisitCount}回\n';
      evaluationText += '主要予定間の最小余裕：${audit.minimumGapMinutes}分\n';
      evaluationText += '時間重複：${audit.overlapCount}件\n';
      evaluationText += '遅延ストレス +5分：${audit.delay5Safe ? '維持' : '影響あり'}\n';
      evaluationText += '遅延ストレス +10分：${audit.delay10Safe ? '維持' : '影響あり'}\n';
      evaluationText += '遅延ストレス +20分：${audit.delay20Safe ? '維持' : '影響あり'}\n';
      evaluationText += '遅延耐性：${audit.robustnessLevel} — ${audit.robustnessMessage}\n';
      evaluationText += '注記：自由時間は追加可否の上限ではありません。追加候補は全日再最適化で判定します。\n';
      evaluationText += '4モードGate：各モードで生成したAI評価用出力の同項目を比較し、目的どおりの差が出ることを確認します。\n';
    }
    if (kDebugMode) {
      evaluationText += _buildDebugOptimizationTrace(controller);
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _PlanTextExportDialog(
          simpleText: simpleText,
          evaluationText: evaluationText,
        );
      },
    );
  }

  Future<void> _confirmClearSchedule() async {
    final controller = _controller;

    if (controller == null || controller.schedule == null) {
      return;
    }

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('プランをクリアしますか？'),
          content: const Text(
            '現在生成されているスケジュールを削除します。'
            '選択した施設や希望条件は削除されません。',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('クリア'),
            ),
          ],
        );
      },
    );

    if (shouldClear == true) {
      controller.clearSchedule();
    }
  }


  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller == null) {
      return const AppScaffold(child: LoadingView(message: 'プラン確認画面を準備中です...'));
    }

    if (controller.isLoading) {
      return AppScaffold(
        child: LoadingView(
          message: 'プランを作成しています\n${controller.generationStatus}',
        ),
      );
    }

    return AppScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useTwoColumns = constraints.maxWidth >= 900;

          if (useTwoColumns) {
            return _DesktopPlanReviewLayout(
              controller: controller,
              timelineScrollController: _timelineScrollController,
              onGeneratePressed: _generateSchedule,
              onClearPressed: _confirmClearSchedule,
              onExportPressed: _showPlanTextExport,
              onFinalizeWishes: _finalizeWishesAndOptimize,
              onRemoveOptionalAddition: _removeOptionalAddition,
            );
          }

          return _MobilePlanReviewLayout(
            controller: controller,
            scrollController: _mobileScrollController,
            onGeneratePressed: _generateSchedule,
            onClearPressed: _confirmClearSchedule,
            onExportPressed: _showPlanTextExport,
            onFinalizeWishes: _finalizeWishesAndOptimize,
            onRemoveOptionalAddition: _removeOptionalAddition,
          );
        },
      ),
    );
  }
}

class _MobilePlanReviewLayout extends StatelessWidget {
  const _MobilePlanReviewLayout({
    required this.controller,
    required this.scrollController,
    required this.onGeneratePressed,
    required this.onClearPressed,
    required this.onExportPressed,
    required this.onFinalizeWishes,
    required this.onRemoveOptionalAddition,
  });

  final ScheduleController controller;
  final ScrollController scrollController;
  final VoidCallback onGeneratePressed;
  final VoidCallback onClearPressed;
  final VoidCallback onExportPressed;
  final Future<void> Function() onFinalizeWishes;
  final Future<void> Function(Facility) onRemoveOptionalAddition;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      interactive: true,
      thickness: 5,
      radius: const Radius.circular(8),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.only(right: 14, bottom: 96),
        children: [
          _PlanOverviewCard(
            controller: controller,
            onGeneratePressed: onGeneratePressed,
            onClearPressed: onClearPressed,
            onExportPressed: onExportPressed,
          ),
          if (controller.schedule != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _PlanCoverageAdviceCard(controller: controller),
            if (kDebugMode) ...[
              const SizedBox(height: AppSpacing.sm),
              _PlanQualityCard(controller: controller),
            ],
          ],
          if (controller.lastAdditionImpact != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _PlanAdditionImpactCard(impact: controller.lastAdditionImpact!),
          ],
          if (controller.optionalAdditionsForCurrentPark.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _OptionalAdditionsCard(
              controller: controller,
              onRemove: onRemoveOptionalAddition,
            ),
          ],
          if (controller.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _GenerationErrorCard(
              message: controller.errorMessage!,
              onClose: controller.clearError,
            ),
          ],
          if (controller.hasUnavailableSelectedFacilities) ...[
            const SizedBox(height: AppSpacing.sm),
            _UnavailableFacilityWarning(
              facilities: controller.unavailableSelectedFacilities,
            ),
          ],
          if (controller.validationIssues.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _ScheduleValidationCard(issues: controller.validationIssues),
          ],
          const SizedBox(height: AppSpacing.sm),
          _ScheduleContent(
            controller: controller,
            onFinalizeWishes: onFinalizeWishes,
          ),
        ],
      ),
    );
  }
}

class _DesktopPlanReviewLayout extends StatelessWidget {
  const _DesktopPlanReviewLayout({
    required this.controller,
    required this.timelineScrollController,
    required this.onGeneratePressed,
    required this.onClearPressed,
    required this.onExportPressed,
    required this.onFinalizeWishes,
    required this.onRemoveOptionalAddition,
  });

  final ScheduleController controller;
  final ScrollController timelineScrollController;
  final VoidCallback onGeneratePressed;
  final VoidCallback onClearPressed;
  final VoidCallback onExportPressed;
  final Future<void> Function() onFinalizeWishes;
  final Future<void> Function(Facility) onRemoveOptionalAddition;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 340,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: AppSpacing.sm, bottom: 48),
            child: Column(
              children: [
                _PlanOverviewCard(
                  controller: controller,
                  onGeneratePressed: onGeneratePressed,
                  onClearPressed: onClearPressed,
                        onExportPressed: onExportPressed,
                                  ),
                if (controller.schedule != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _PlanCoverageAdviceCard(controller: controller),
                  if (kDebugMode) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _PlanQualityCard(controller: controller),
                  ],
                ],
                if (controller.lastAdditionImpact != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _PlanAdditionImpactCard(impact: controller.lastAdditionImpact!),
                ],
                if (controller.optionalAdditionsForCurrentPark.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _OptionalAdditionsCard(
                    controller: controller,
                    onRemove: onRemoveOptionalAddition,
                  ),
                ],
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _GenerationErrorCard(
                    message: controller.errorMessage!,
                    onClose: controller.clearError,
                  ),
                ],
                if (controller.hasUnavailableSelectedFacilities) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _UnavailableFacilityWarning(
                    facilities: controller.unavailableSelectedFacilities,
                  ),
                ],
                if (controller.validationIssues.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _ScheduleValidationCard(issues: controller.validationIssues),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Scrollbar(
            controller: timelineScrollController,
            thumbVisibility: true,
            interactive: true,
            thickness: 5,
            radius: const Radius.circular(8),
            child: ListView(
              controller: timelineScrollController,
              padding: const EdgeInsets.only(right: 14, bottom: 48),
              children: [
                _ScheduleContent(
                  controller: controller,
                  onFinalizeWishes: onFinalizeWishes,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


class _PlanQualityCard extends StatelessWidget {
  const _PlanQualityCard({required this.controller});

  final ScheduleController controller;

  List<Widget> _buildOutsideParkDebugRows(BuildContext context) {
    final schedule = controller.schedule;
    if (schedule == null) return const <Widget>[];
    final facilityById = {
      for (final facility in controller.selectedFacilitiesForCurrentPark)
        facility.id: facility,
    };
    final outsideItems = schedule.items.where((item) {
      final facilityId = item.facilityId;
      if (facilityId == null) return false;
      return facilityById[facilityId]?.requiresParkExit ?? false;
    }).toList(growable: false);
    if (outsideItems.isEmpty) return const <Widget>[];

    final colors = Theme.of(context).colorScheme;
    return <Widget>[
      const SizedBox(height: 8),
      Text(
        'DEBUG パーク外予定検証',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      for (final item in outsideItems)
        Text(
          '${item.title}: ${item.timeRangeLabel} / 退出・移動・予約・再入園を固定確保 = PASS',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final audit = controller.planQualityAudit;
    if (audit == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_outlined, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'プラン品質チェック',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('待ち時間 ${audit.totalWaitMinutes}分 ・ 自由時間 ${audit.totalFreeMinutes}分 ・ 最大連続 ${audit.largestFreeBlockMinutes}分'),
          const SizedBox(height: 4),
          Text('移動 ${audit.totalMovementMinutes}分 ・ エリア跨ぎ ${audit.areaCrossingCount}回 ・ 再訪 ${audit.areaRevisitCount}回'),
          const SizedBox(height: 4),
          Text('自由枠 ${audit.freeBlockCount}個 ・ 最小予定間余裕 ${audit.minimumGapMinutes}分 ・ 細切れ ${audit.smallFreeBlockCount}個 ・ 重なり ${audit.overlapCount}件'),
          const SizedBox(height: 6),
          Text(
            '遅延ストレス +5/+10/+20分：${audit.delay5Safe ? '維持' : '影響'} / ${audit.delay10Safe ? '維持' : '影響'} / ${audit.delay20Safe ? '維持' : '影響'}\n遅延耐性：${audit.robustnessLevel} — ${audit.robustnessMessage}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          ..._buildOutsideParkDebugRows(context),
          const SizedBox(height: 4),
          Text(
            'この表示は品質評価です。追加候補の可否は空き時間の単純差し引きではなく、引き続き一日全体の再最適化で判定します。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PlanCoverageAdviceCard extends StatelessWidget {
  const _PlanCoverageAdviceCard({required this.controller});

  final ScheduleController controller;

  @override
  Widget build(BuildContext context) {
    final advice = controller.coverageAdvice;
    final colorScheme = Theme.of(context).colorScheme;
    final required = controller.requiredFacilitiesForCurrentPark;
    final scheduledIds = controller.schedule?.items
            .map((item) => item.facilityId)
            .whereType<String>()
            .toSet() ??
        const <String>{};
    final achieved = required.where((facility) => scheduledIds.contains(facility.id)).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'やりたいこと達成状況 / DPAアドバイス',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (controller.isAnalyzingCoverage)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'やりたいこと：$achieved/${required.length}件達成',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            achieved == required.length
                ? '元の「やりたいこと」はすべてプランに入っています。DPAによる達成数改善は不要です。'
                : 'ここでは元の「やりたいこと」だけを確認します。追加候補は達成数に含めません。未達成がある場合はDPA利用による改善を分析できます。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (controller.coverageAnalysisError != null) ...[
            const SizedBox(height: 10),
            Text(
              controller.coverageAnalysisError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ],
          if (advice == null &&
              !controller.isAnalyzingCoverage &&
              achieved < required.length) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: controller.analyzePlanCoverage,
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('DPA利用で改善できるか分析'),
            ),
          ],
          if (advice != null) ...[
            const SizedBox(height: 12),
            _CoverageHeadline(advice: advice),
            if (advice.unmetFacilities.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'プランに入らなかった希望',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              for (final item in advice.unmetFacilities) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 7),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (item.firstRescuedAtDpaCount != null)
                            _AdvicePill(
                              label: 'DPA ${item.firstRescuedAtDpaCount}個で採用',
                              icon: Icons.confirmation_number_outlined,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(item.reason, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 8),
            Text(
              'DPA個数別シミュレーション',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final scenario in advice.scenarios)
                  _AdvicePill(
                    icon: scenario.dpaCount == 0
                        ? Icons.directions_walk_outlined
                        : Icons.confirmation_number_outlined,
                    label: 'DPA ${scenario.dpaCount}個：${_coverageCount(scenario)}/${advice.totalDesiredCount}',
                    emphasized: advice.minimumDpaCountForAll == scenario.dpaCount,
                  ),
              ],
            ),
            if (advice.dpaAcquisitionOrder.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    controller.selectedParkId == 'tokyo_disneysea'
                        ? 'ディズニーシー DPA取得優先順'
                        : 'DPA取得優先順',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: '在庫のリアルタイム予測ではなく、現在の希望優先度・通常待機の負担・時間短縮を基準にした順番です。取得済みDPAは除外します。',
                    child: Icon(Icons.info_outline, size: 17, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final item in _visibleDpaOrder(advice))
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          '${item.order}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            Text(item.reason, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                '※ 実際の販売状況・次回購入可能時刻は当日の公式アプリ表示を優先してください。取得後は「当日ガイド」から取得実績を入力すると、残り順を再評価します。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: controller.isAnalyzingCoverage
                  ? null
                  : controller.analyzePlanCoverage,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('再分析'),
            ),
          ],
        ],
      ),
    );
  }

  static int _coverageCount(PlanCoverageScenario scenario) {
    return scenario.scheduledDesiredCount;
  }

  static List<DpaAcquisitionAdvice> _visibleDpaOrder(PlanCoverageAdvice advice) {
    final targetCount = advice.minimumDpaCountForAll ?? advice.simulatedMaxDpaCount;
    if (targetCount <= 0) return const <DpaAcquisitionAdvice>[];
    return advice.dpaAcquisitionOrder.take(targetCount).toList(growable: false);
  }
}

class _OptionalAdditionsCard extends StatelessWidget {
  const _OptionalAdditionsCard({
    required this.controller,
    required this.onRemove,
  });

  final ScheduleController controller;
  final Future<void> Function(Facility facility) onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final adopted = controller.scheduledOptionalAdditions;
    final notAdopted = controller.unscheduledOptionalAdditions;
    final total = adopted.length + notAdopted.length;
    String? scheduledTimeFor(Facility facility) {
      final items = controller.schedule?.items ?? const <ScheduleItem>[];
      for (final item in items) {
        if (item.facilityId == facility.id) {
          final hour = item.startHour.toString().padLeft(2, '0');
          final minute = item.startMinute.toString().padLeft(2, '0');
          return '$hour:$minute';
        }
      }
      return null;
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.playlist_add_check_circle_outlined,
                  size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '追加候補（行けたら行く）',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '追加結果：${adopted.length}/$total件がプランに入りました',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'やりたいことは100%維持したまま判定しています。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '「やりたいこと」で保存した希望を優先します。追加候補は、その希望を崩さず入る場合だけプランへ採用します。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          if (adopted.isNotEmpty) ...[
            const SizedBox(height: 9),
            for (final facility in adopted)
              _OptionalAdditionRow(
                facility: facility,
                status: scheduledTimeFor(facility) != null
                    ? '✓ プランに入りました（${scheduledTimeFor(facility)}）'
                    : '✓ プランに入りました',
                onRemove: onRemove,
              ),
          ],
          if (notAdopted.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final facility in notAdopted)
              _OptionalAdditionRow(
                facility: facility,
                status: '今回は入りませんでした（候補として保持）',
                detail: controller.optionalRejectionReason(facility.id),
                onRemove: onRemove,
              ),
            const SizedBox(height: 3),
            Text(
              '見送り候補も削除できます。削除後は残りの追加候補で一日全体を組み直します。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionalAdditionRow extends StatelessWidget {
  const _OptionalAdditionRow({
    required this.facility,
    required this.status,
    required this.onRemove,
    this.detail,
  });

  final Facility facility;
  final String status;
  final String? detail;
  final Future<void> Function(Facility facility) onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${facility.name}：$status'),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: '追加候補から削除',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => onRemove(facility),
          ),
        ],
      ),
    );
  }
}

class _PlanAdditionImpactCard extends StatelessWidget {
  const _PlanAdditionImpactCard({required this.impact});

  final PlanAdditionImpact impact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                impact.hasTradeOff
                    ? Icons.compare_arrows_outlined
                    : Icons.check_circle_outline,
                size: 20,
                color: impact.hasTradeOff ? colors.error : colors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  impact.hasTradeOff ? '追加によるプランへの影響' : '追加後も希望を維持できました',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(impact.explanation),
          if (impact.hasTradeOff) ...[
            const SizedBox(height: 8),
            Text(
              '入らなくなった希望：${impact.lostFacilityNames.join('、')}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '追加した希望を残すか、入らなくなった希望を優先するかを確認してください。'
              'DPA分析に短縮案が出ている場合は、その案も比較できます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoverageHeadline extends StatelessWidget {
  const _CoverageHeadline({required this.advice});

  final PlanCoverageAdvice advice;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final all = advice.allDesiredScheduled;
    final minimum = advice.minimumDpaCountForAll;
    final message = all
        ? '現在のプランで「やりたいこと」${advice.totalDesiredCount}/${advice.totalDesiredCount}件を体験できます。'
        : minimum != null
            ? '現在は${advice.currentScheduledCount}/${advice.totalDesiredCount}件。シミュレーション上、DPAを最少$minimum個使うと全件を組み込めます。'
            : '現在は${advice.currentScheduledCount}/${advice.totalDesiredCount}件。DPAを最大${advice.simulatedMaxDpaCount}個まで試しても全件達成にはなりません。';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: all ? colorScheme.primaryContainer : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: all ? colorScheme.onPrimaryContainer : colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AdvicePill extends StatelessWidget {
  const _AdvicePill({
    required this.label,
    required this.icon,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: emphasized
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }
}

class _PlanOverviewCard extends StatelessWidget {
  const _PlanOverviewCard({
    required this.controller,
    required this.onGeneratePressed,
    required this.onClearPressed,
    required this.onExportPressed,
  });

  final ScheduleController controller;
  final VoidCallback onGeneratePressed;
  final VoidCallback onClearPressed;
  final VoidCallback onExportPressed;

  @override
  Widget build(BuildContext context) {
    final schedule = controller.schedule;
    final manualRepeatCount = schedule?.items
            .where((item) => item.id.startsWith('manual_repeat_'))
            .length ??
        0;
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(
                  controller.selectedParkIcon,
                  size: 21,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.selectedParkName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '選択施設 '
                      '${controller.selectedFacilityCount}件',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _OverviewInformationRow(
            icon: Icons.edit_calendar_outlined,
            label: 'プランの内容を確認し、必要なら予定を追加・変更できます。',
          ),
          const SizedBox(height: 7),
          _OverviewInformationRow(
            icon: Icons.auto_awesome_outlined,
            label: schedule == null
                ? 'スケジュールは未生成です'
                : manualRepeatCount == 0
                    ? '${schedule.items.length}件の予定を生成済み'
                    : '${schedule.items.length}件の予定を生成済み'
                        '（手動再乗車 $manualRepeatCount件）',
          ),
          if (schedule != null) ...[
            const SizedBox(height: 7),
            _OverviewInformationRow(
              icon: Icons.update_outlined,
              label: '更新：${_formatDateTime(schedule.createdAt)}',
            ),
          ],
          if (controller.hasStaleSchedule) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '表示中のプランは別のパークで生成されています。'
                '現在のパークで再生成してください。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: controller.canGenerateSchedule ? onGeneratePressed : null,
              icon: Icon(
                schedule == null ? Icons.auto_awesome : Icons.refresh,
                size: 19,
              ),
              label: Text(schedule == null ? '仮プランを作る' : '予定を追加・変更して組み直す'),
            ),
          ),
          if (schedule != null) ...[
            const SizedBox(height: 6),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              leading: const Icon(Icons.more_horiz, size: 20),
              title: const Text('その他の操作'),
              subtitle: const Text('出力・履歴・クリア'),
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onExportPressed,
                    icon: const Icon(Icons.text_snippet_outlined, size: 19),
                    label: const Text('プランを文章で出力'),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controller.canUndo
                            ? controller.undoScheduleChange
                            : null,
                        icon: const Icon(Icons.undo, size: 18),
                        label: const Text('元に戻す'),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controller.canRedo
                            ? controller.redoScheduleChange
                            : null,
                        icon: const Icon(Icons.redo, size: 18),
                        label: const Text('やり直す'),
                      ),
                    ),
                  ],
                ),
                if (controller.historyCount > 0) ...[
                  const SizedBox(height: 5),
                  Text(
                    '履歴 ${controller.historyCount}件（最大10件）',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 7),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onClearPressed,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('生成結果をクリア'),
                  ),
                ),
              ],
            ),
          ],
          if (!controller.canGenerateSchedule) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'プラン編集画面で、現在のパークの施設を追加してください。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();

    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '${local.year}/$month/$day $hour:$minute';
  }
}

class _OverviewInformationRow extends StatelessWidget {
  const _OverviewInformationRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _GenerationErrorCard extends StatelessWidget {
  const _GenerationErrorCard({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: '閉じる',
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.close,
              size: 18,
              color: colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleValidationCard extends StatelessWidget {
  const _ScheduleValidationCard({required this.issues});

  final List<ScheduleValidationIssue> issues;

  @override
  Widget build(BuildContext context) {
    final important = issues
        .where(
          (issue) => issue.severity != ScheduleValidationSeverity.information,
        )
        .toList(growable: false);
    final displayIssues = important.isEmpty ? issues : important;
    final hasError = displayIssues.any(
      (issue) => issue.severity == ScheduleValidationSeverity.error,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasError ? Icons.error_outline : Icons.verified_outlined,
                color: hasError ? colorScheme.error : colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                hasError ? 'プラン安全確認' : 'プラン確認結果',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final issue in displayIssues)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text('・${issue.message}'),
            ),
        ],
      ),
    );
  }
}

class _UnavailableFacilityWarning extends StatelessWidget {
  const _UnavailableFacilityWarning({required this.facilities});

  final List<Facility> facilities;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4),
        leading: Icon(Icons.warning_amber_outlined, color: colorScheme.error),
        title: Text(
          '追加できない施設があります',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.error,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${facilities.length}件はスケジュール生成から除外されます',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: [
          for (final facility in facilities)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.block_outlined, size: 18),
              title: Text(
                facility.name,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(facility.operatingStatusDisplayLabel),
            ),
        ],
      ),
    );
  }
}

class _ScheduleContent extends StatelessWidget {
  const _ScheduleContent({
    required this.controller,
    required this.onFinalizeWishes,
  });

  final ScheduleController controller;
  final Future<void> Function() onFinalizeWishes;

  @override
  Widget build(BuildContext context) {
    final schedule = controller.schedule;

    if (!controller.canGenerateSchedule) {
      return const EmptyState(
        title: '施設が選択されていません',
        message: 'プラン編集画面で、行きたい施設を追加してください。',
        icon: Icons.add_location_alt_outlined,
      );
    }

    if (schedule == null) {
      return const EmptyState(
        title: 'プランはまだ生成されていません',
        message:
            '選択施設と希望条件を確認し、'
            '「プランを生成」を押してください。',
        icon: Icons.auto_awesome_outlined,
      );
    }

    if (controller.hasStaleSchedule) {
      return const EmptyState(
        title: 'パークが変更されています',
        message:
            '現在選択中のパークに合わせて、'
            'プランを再生成してください。',
        icon: Icons.sync_problem_outlined,
      );
    }

    return _ScheduleTimeline(
      schedule: schedule,
      controller: controller,
      onFinalizeWishes: onFinalizeWishes,
    );
  }
}

class _ScheduleTimeline extends StatelessWidget {
  const _ScheduleTimeline({
    required this.schedule,
    required this.controller,
    required this.onFinalizeWishes,
  });

  final DaySchedule schedule;
  final ScheduleController controller;
  final Future<void> Function() onFinalizeWishes;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_outlined, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '一日のプラン',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${schedule.items.length}件',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _PlanFreeTimeSummary(
            schedule: schedule,
            controller: controller,
            onFinalizeWishes: onFinalizeWishes,
          ),
          const SizedBox(height: AppSpacing.md),
          if (schedule.items.isEmpty)
            const EmptyState(
              title: '予定がありません',
              message: '条件を変更して、プランを再生成してください。',
            )
          else
            for (var index = 0; index < schedule.items.length; index++) ...[
              if (index > 0) ...[
                if (_planVisibleBufferMinutes(
                      schedule.items[index - 1],
                      schedule.items[index],
                    ) >=
                    30)
                  _PlanBufferGapCard(
                    startMinutes: _planScheduleEndMinutes(
                      schedule.items[index - 1],
                    ),
                    endMinutes: _planScheduleStartMinutes(schedule.items[index]),
                  )
                else if (_planVisibleBufferMinutes(
                          schedule.items[index - 1],
                          schedule.items[index],
                        ) >=
                        15)
                  _PlanCompactBufferGap(
                    minutes: _planVisibleBufferMinutes(
                      schedule.items[index - 1],
                      schedule.items[index],
                    ),
                  ),
              ],
              _ScheduleTimelineItem(
                item: schedule.items[index],
                facility: controller.facilityById(
                  schedule.items[index].facilityId,
                ),
                preference: controller.preferenceByFacilityId(
                  schedule.items[index].facilityId,
                ),
                controller: controller,
                isFirst: index == 0,
                isLast: index == schedule.items.length - 1,
              ),
            ],
        ],
      ),
    );
  }
}

int _planScheduleStartMinutes(ScheduleItem item) {
  return item.startHour * 60 + item.startMinute;
}

int _planScheduleEndMinutes(ScheduleItem item) {
  return item.endHour * 60 + item.endMinute;
}

int _planVisibleBufferMinutes(ScheduleItem previous, ScheduleItem next) {
  final gap =
      _planScheduleStartMinutes(next) - _planScheduleEndMinutes(previous);
  return gap > 0 ? gap : 0;
}

String _planClockLabel(int minutes) {
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _PlanCompactBufferGap extends StatelessWidget {
  const _PlanCompactBufferGap({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 80, bottom: 6),
      child: Row(
        children: [
          Icon(
            Icons.directions_walk_outlined,
            size: 15,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            '移動・余裕 $minutes分',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _PlanBufferGapCard extends StatelessWidget {
  const _PlanBufferGapCard({
    required this.startMinutes,
    required this.endMinutes,
  });

  final int startMinutes;
  final int endMinutes;

  @override
  Widget build(BuildContext context) {
    final minutes = endMinutes - startMinutes;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.directions_walk_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '移動・余裕時間 $minutes分'
                '（${_planClockLabel(startMinutes)} - ${_planClockLabel(endMinutes)}）',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


String _planDurationLabel(int minutes) {
  if (minutes <= 0) return '0分';
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (hours == 0) return '$remainingMinutes分';
  if (remainingMinutes == 0) return '$hours時間';
  return '$hours時間$remainingMinutes分';
}

class _PlanFreeTimeSummary extends StatefulWidget {
  const _PlanFreeTimeSummary({
    required this.schedule,
    required this.controller,
    required this.onFinalizeWishes,
  });

  final DaySchedule schedule;
  final ScheduleController controller;
  final Future<void> Function() onFinalizeWishes;

  @override
  State<_PlanFreeTimeSummary> createState() => _PlanFreeTimeSummaryState();
}

class _PlanFreeTimeSummaryState extends State<_PlanFreeTimeSummary> {
  String? _loadingGapId;
  bool _isLoadingAll = false;

  Future<void> _rebuildWholePlan() async {
    if (_loadingGapId != null || _isLoadingAll) return;
    setState(() => _isLoadingAll = true);
    final choices = await widget.controller.loadPlanAdditionChoices();
    if (!mounted) return;
    setState(() => _isLoadingAll = false);
    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('追加できる施設データがありません。'),
      ));
      return;
    }
    final selected = await showModalBottomSheet<PlanAdditionChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.90,
        child: _PlanAdditionPickerSheet(choices: choices),
      ),
    );
    if (selected == null || !mounted) return;

    setState(() => _isLoadingAll = true);
    final result = await widget.controller.addPlanAdditionChoice(selected);
    if (!mounted) return;
    setState(() => _isLoadingAll = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        result.message.isNotEmpty
            ? result.message
            : (result.added
                ? '${selected.facility.name}を追加候補として保存しました。残り余力は約${_planDurationLabel(result.remainingMinutes)}です。'
                : '${selected.facility.name}を追加候補として保存できませんでした。'),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final freeTimes = widget.schedule.items
        .where((item) => item.type.name == 'breakTime')
        .where((item) => _planScheduleEndMinutes(item) > _planScheduleStartMinutes(item))
        .toList(growable: false)
      ..sort((a, b) => _planScheduleStartMinutes(a).compareTo(_planScheduleStartMinutes(b)));
    if (freeTimes.isEmpty) return const SizedBox.shrink();
    final totalMinutes = freeTimes.fold<int>(0, (sum, item) =>
        sum + _planScheduleEndMinutes(item) - _planScheduleStartMinutes(item));
    final standbyWaitMinutes = widget.schedule.items.fold<int>(
      0,
      (sum, item) => sum + (item.standbyWaitMinutes ?? 0),
    );
    final slackGuidance = switch (totalMinutes) {
      < 30 =>
        '空きはかなり少なめです。移動・トイレ・ショップなどの余裕として残すのがおすすめです。',
      < 60 =>
        '空きは少なめです。休憩・買い物・短時間で利用できる施設向けです。',
      < 90 =>
        'もう1つ予定を追加できる可能性がありますが、待ち時間の変動を考えると、休憩・買い物などの余裕として残すのもおすすめです。',
      _ =>
        '追加候補を検討しやすい余裕があります。選んだ候補は一日全体を組み直して入るか確認します。',
    };
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'このプランの内容を確認してください',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          '待ち時間 ${_planDurationLabel(standbyWaitMinutes)} ・ '
          '自由時間 ${_planDurationLabel(totalMinutes)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          slackGuidance,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          '内容を変えたい場合は予定を追加・変更できます。'
          '元のやりたいことは維持したまま一日全体を組み直します。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _loadingGapId == null && !_isLoadingAll ? _rebuildWholePlan : null,
            icon: _isLoadingAll
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.explore_outlined),
            label: Text(_isLoadingAll ? '施設を読み込んでいます…' : '予定を追加・変更する'),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _loadingGapId == null && !_isLoadingAll
                ? widget.onFinalizeWishes
                : null,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('この内容で最終プランを作る'),
          ),
        ),
        Text(
          '次に、バランス・待ち時間・移動・まとまった自由時間から組み方を選びます。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ]),
    );
  }
}

class _FreeTimeDurationPanel extends StatelessWidget {
  const _FreeTimeDurationPanel({required this.item});

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final minutes = _planScheduleEndMinutes(item) - _planScheduleStartMinutes(item);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_outlined, size: 18, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 7),
          Text(
            '使える空き時間',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          Text(
            _planDurationLabel(minutes),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTimelineItem extends StatefulWidget {
  const _ScheduleTimelineItem({
    required this.item,
    required this.facility,
    required this.preference,
    required this.controller,
    required this.isFirst,
    required this.isLast,
  });

  final ScheduleItem item;
  final Facility? facility;
  final PlanPreference? preference;
  final ScheduleController controller;
  final bool isFirst;
  final bool isLast;

  @override
  State<_ScheduleTimelineItem> createState() {
    return _ScheduleTimelineItemState();
  }
}

class _ScheduleTimelineItemState extends State<_ScheduleTimelineItem> {
  bool _isExpanded = false;
  bool _isLoadingFreeTimeChoices = false;
  bool _isLoadingRepeatChoices = false;

  ScheduleItem get item {
    return widget.item;
  }

  Facility? get facility {
    return widget.facility;
  }

  PlanPreference? get preference {
    return widget.preference;
  }

  bool get _hasDetails {
    return (item.reason?.trim().isNotEmpty ?? false) ||
        (item.note?.trim().isNotEmpty ?? false);
  }

  bool get _isFreeTime {
    return item.type.name == 'breakTime';
  }

  bool get _usesUnlimitedRide {
    final source = item.waitEstimateSource?.trim() ?? '';
    return source.startsWith('バケーションパッケージ乗り放題') ||
        source.startsWith('バケパ乗り放題');
  }

  bool get _canAddPlannedRepeat {
    return facility?.category == FacilityCategory.attraction &&
        _usesUnlimitedRide;
  }

  bool get _canEditPlanningAccess {
    final target = facility;
    final p = preference;
    if (target == null || p == null) return false;

    if (p.accessMethod == FacilityAccessMethod.reservation) {
      return _supportsReservation(target);
    }

    return switch (p.accessMethod) {
      FacilityAccessMethod.dpa ||
      FacilityAccessMethod.standbyPass => true,
      FacilityAccessMethod.priorityPass => false,
      // エントリー受付の当落は当日ガイドで扱う。
      FacilityAccessMethod.reservation => true,
      FacilityAccessMethod.entryRequest ||
      FacilityAccessMethod.standby ||
      FacilityAccessMethod.freeSeating => false,
    };
  }

  Future<void> _removePlannedFacility() async {
    final target = facility;
    if (target == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('予定から外しますか？'),
        content: Text(
          '${target.name}をやりたいことと現在のプランから外し、残りの予定を再構成します。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('外して再構成'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final appState = AppStateScope.of(context);
    appState.removeFacility(target.id);
    final controller = ScheduleController(appState);
    await controller.generateSchedule();
    controller.dispose();
  }

  Future<void> _showPlannedRepeatRide() async {
    final target = facility;
    if (target == null || _isLoadingRepeatChoices) return;

    setState(() => _isLoadingRepeatChoices = true);
    final choices = await widget.controller.loadRepeatRideChoicesForFacility(
      target.id,
    );
    if (!mounted) return;
    setState(() => _isLoadingRepeatChoices = false);

    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('このアトラクションを追加できる20分以上の空き時間がありません。'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final selected = await showModalBottomSheet<FreeTimeImprovementChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.72,
          child: Scaffold(
            appBar: AppBar(
              title: Text('${target.name}をもう一度'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: '閉じる',
                ),
              ],
            ),
            body: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              itemCount: choices.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final choice = choices[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.repeat)),
                  title: Text(
                    '${choice.plannedStartLabel} - ${choice.plannedEndLabel}',
                  ),
                  subtitle: Text(
                    '${choice.repeatNumber ?? 2}回目として手動追加・前後の予定は維持',
                  ),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => Navigator.of(sheetContext).pop(choice),
                );
              },
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;

    await widget.controller.applyFreeTimeImprovement(selected);
    if (!mounted) return;
    if (widget.controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.controller.errorMessage!)),
      );
      return;
    }

    final noticeWidth = MediaQuery.sizeOf(context).width;
    final noticeHorizontalMargin =
        noticeWidth >= 900 ? (noticeWidth - 560) / 2 : 16.0;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          noticeHorizontalMargin,
          0,
          noticeHorizontalMargin,
          noticeWidth >= 900 ? 144.0 : 96.0,
        ),
        duration: const Duration(seconds: 4),
        content: Text('${target.name}を${selected.repeatNumber ?? 2}回目として予定へ追加しました。'),
      ),
    );
  }

  Future<void> _showFreeTimeImprovement() {
    return _showFreeTimeImprovementFor(item);
  }

  Future<void> _showFreeTimeImprovementFor(ScheduleItem targetItem) async {
    if (_isLoadingFreeTimeChoices) return;
    setState(() => _isLoadingFreeTimeChoices = true);
    final choices = await widget.controller.loadFreeTimeImprovementChoices(targetItem);
    if (!mounted) return;
    setState(() => _isLoadingFreeTimeChoices = false);

    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('この空き時間に、前後の移動まで含めて安全に入る候補がありません。'),
        ),
      );
      return;
    }

    final contextInfo = _freeTimeContext(targetItem);
    final selected = await showModalBottomSheet<FreeTimeImprovementChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.90,
          child: _FreeTimeImprovementSheet(
            freeTimeItem: targetItem,
            choices: choices,
            previousTitle: contextInfo.previousTitle,
            nextTitle: contextInfo.nextTitle,
          ),
        );
      },
    );
    if (selected == null || !mounted) return;

    await widget.controller.applyFreeTimeImprovement(selected);
    if (!mounted) return;
    if (widget.controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.controller.errorMessage!)),
      );
      return;
    }

    final remaining = _largestRemainingFreeTime(targetItem);
    final action = selected.kind == FreeTimeImprovementKind.performance
        ? '公演を追加して再生成しました'
        : '${selected.plannedStartLabel}頃に、既存の予定を維持したまま空き時間へ追加しました';
    final remainingMinutes = remaining == null
        ? 0
        : _scheduleItemDurationMinutes(remaining);
    final noticeWidth = MediaQuery.sizeOf(context).width;
    final noticeHorizontalMargin =
        noticeWidth >= 900 ? (noticeWidth - 560) / 2 : 16.0;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          noticeHorizontalMargin,
          0,
          noticeHorizontalMargin,
          noticeWidth >= 900 ? 144.0 : 96.0,
        ),
        duration: const Duration(seconds: 4),
        content: Text('${selected.facility.name}を$action。'),
        action: remaining == null || remainingMinutes < 20
            ? null
            : SnackBarAction(
                label: '残り$remainingMinutes分を改善',
                onPressed: () {
                  if (!mounted) return;
                  _showFreeTimeImprovementFor(remaining);
                },
              ),
      ),
    );
  }

  ({String? previousTitle, String? nextTitle}) _freeTimeContext(
    ScheduleItem targetItem,
  ) {
    final currentSchedule = widget.controller.schedule;
    if (currentSchedule == null) {
      return (previousTitle: null, nextTitle: null);
    }
    final sorted = [...currentSchedule.items]
      ..sort((a, b) {
        final aStart = a.startHour * 60 + a.startMinute;
        final bStart = b.startHour * 60 + b.startMinute;
        return aStart.compareTo(bStart);
      });
    final index = sorted.indexWhere((candidate) => candidate.id == targetItem.id);
    if (index < 0) {
      return (previousTitle: null, nextTitle: null);
    }
    return (
      previousTitle: index > 0 ? sorted[index - 1].title : null,
      nextTitle: index + 1 < sorted.length ? sorted[index + 1].title : null,
    );
  }

  ScheduleItem? _largestRemainingFreeTime(ScheduleItem originalGap) {
    final currentSchedule = widget.controller.schedule;
    if (currentSchedule == null) return null;
    final originalStart = originalGap.startHour * 60 + originalGap.startMinute;
    final originalEnd = originalGap.endHour * 60 + originalGap.endMinute;
    final candidates = currentSchedule.items.where((candidate) {
      if (candidate.type.name != 'breakTime') return false;
      final start = candidate.startHour * 60 + candidate.startMinute;
      final end = candidate.endHour * 60 + candidate.endMinute;
      return start >= originalStart && end <= originalEnd && end - start >= 20;
    }).toList(growable: false);
    if (candidates.isEmpty) return null;
    candidates.sort(
      (left, right) => _scheduleItemDurationMinutes(right)
          .compareTo(_scheduleItemDurationMinutes(left)),
    );
    return candidates.first;
  }

  int _scheduleItemDurationMinutes(ScheduleItem targetItem) {
    final start = targetItem.startHour * 60 + targetItem.startMinute;
    final end = targetItem.endHour * 60 + targetItem.endMinute;
    return end - start;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final scheduleStyle = _scheduleItemStyle(item.type.name);

    final categoryStyle = facility == null
        ? null
        : FacilityVisualStyle.categoryStyle(facility!);

    final timelineColor = categoryStyle?.backgroundColor ?? scheduleStyle.color;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 68,
            child: Column(
              children: [
                Text(
                  item.startTimeLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  item.endTimeLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 28,
            child: Column(
              children: [
                if (!widget.isFirst)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colorScheme.outlineVariant,
                    ),
                  )
                else
                  const Expanded(child: SizedBox.shrink()),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: timelineColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.surface, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: timelineColor.withValues(alpha: 0.25),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                if (!widget.isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colorScheme.outlineVariant,
                    ),
                  )
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ScheduleTypeBadge(item: item, style: scheduleStyle),
                        const Spacer(),
                        Text(
                          item.timeRangeLabel,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (item.id.startsWith('manual_repeat_'))
                          IconButton(
                            tooltip: 'この再乗車だけ削除',
                            onPressed: () {
                              final removed = widget.controller.removeManualRepeat(
                                item.id,
                              );
                              if (!removed || !mounted) return;
                              final noticeWidth =
                                  MediaQuery.sizeOf(context).width;
                              final noticeHorizontalMargin =
                                  noticeWidth >= 900
                                      ? (noticeWidth - 560) / 2
                                      : 16.0;
                              final messenger =
                                  ScaffoldMessenger.of(context);
                              messenger.hideCurrentSnackBar();
                              messenger.showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  margin: EdgeInsets.fromLTRB(
                                    noticeHorizontalMargin,
                                    0,
                                    noticeHorizontalMargin,
                                    noticeWidth >= 900 ? 144.0 : 96.0,
                                  ),
                                  duration: const Duration(seconds: 4),
                                  content: Text(
                                    '${item.title}を削除し、空き時間に戻しました。',
                                  ),
                                  action: SnackBarAction(
                                    label: '元に戻す',
                                    onPressed:
                                        widget.controller.undoScheduleChange,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.delete_outline),
                          )
                        else if (facility != null) ...[
                          if (_canEditPlanningAccess)
                            IconButton(
                              tooltip: '取得・予約予定を編集して再生成',
                              onPressed: () async {
                                final appState = AppStateScope.of(context);
                                final changed =
                                    await showFixedScheduleEditorSheet(
                                      context: context,
                                      appState: appState,
                                      facility: facility!,
                                    );
                                if (!changed || !context.mounted) return;
                                final controller = ScheduleController(appState);
                                await controller.generateSchedule();
                                controller.dispose();
                              },
                              icon: const Icon(Icons.edit_calendar_outlined),
                            ),
                          IconButton(
                            tooltip: 'この予定を外して再構成',
                            onPressed: _removePlannedFacility,
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ],
                    ),
                    if (facility != null) ...[
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _TimelineCategoryBadge(facility: facility!),
                          _TimelineAreaBadge(areaId: facility!.areaId),
                          ..._buildPreferenceBadges(
                            facility: facility!,
                            preference: preference,
                          ),
                          if (item.id.startsWith('manual_repeat_'))
                            const _PreferenceBadge(
                              icon: Icons.repeat,
                              label: 'バケパ乗り放題・手動再乗車',
                              foregroundColor: Color(0xFF4F378B),
                              backgroundColor: Color(0xFFF1ECFF),
                              borderColor: Color(0xFFC8B8F8),
                            ),
                        ],
                      ),
                    ],
                    if (_canAddPlannedRepeat) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLoadingRepeatChoices
                              ? null
                              : _showPlannedRepeatRide,
                          icon: _isLoadingRepeatChoices
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.repeat),
                          label: Text(
                            _isLoadingRepeatChoices
                                ? '空き時間を確認中...'
                                : 'もう一度乗る予定を追加',
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '事前計画として追加します。Plannerが自動で2回目を入れることはありません。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    if (_shouldShowLotteryFallback(
                      facility: facility,
                      preference: preference,
                    )) ...[
                      const SizedBox(height: 8),
                      _LotteryFallbackInformation(
                        action: preference!.lotteryFallbackAction,
                      ),
                    ],
                    if (_isFreeTime) ...[
                      const SizedBox(height: 10),
                      _FreeTimeDurationPanel(item: item),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: _isLoadingFreeTimeChoices
                              ? null
                              : _showFreeTimeImprovement,
                          icon: _isLoadingFreeTimeChoices
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_fix_high_outlined),
                          label: Text(
                            _isLoadingFreeTimeChoices
                                ? '候補を計算中...'
                                : 'この空き時間を改善',
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '前後の移動と待ち時間を含め、この枠に収まる候補だけを表示します。自動では追加しません。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    if (_hasDetails) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          icon: AnimatedRotation(
                            turns: _isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                            ),
                          ),
                          label: Text(_isExpanded ? '詳細を閉じる' : '理由・メモを見る'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 30),
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      if (_isExpanded) ...[
                        const SizedBox(height: 2),
                        _ScheduleItemDetails(item: item),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPreferenceBadges({
    required Facility facility,
    required PlanPreference? preference,
  }) {
    if (preference == null) {
      return const [];
    }

    final badges = <Widget>[];
    final isShowOrParade =
        facility.category == FacilityCategory.show ||
        facility.category == FacilityCategory.parade;

    if (preference.fixedTimeStatus == FixedTimeStatus.confirmed) {
      badges.add(
        const _PreferenceBadge(
          icon: Icons.lock_outline,
          label: '固定予定',
          foregroundColor: Color(0xFF8A4B08),
          backgroundColor: Color(0xFFFFF3E0),
          borderColor: Color(0xFFFFCC80),
        ),
      );
    }

    if (isShowOrParade &&
        preference.preferredPerformanceTime.trim().isNotEmpty) {
      badges.add(
        _PreferenceBadge(
          icon: Icons.schedule_outlined,
          label: '${preference.preferredPerformanceTime} 公演',
          foregroundColor: const Color(0xFF6A3DA1),
          backgroundColor: const Color(0xFFF2EAFE),
          borderColor: const Color(0xFFC9AEEF),
        ),
      );
    }

    if (_supportsReservation(facility) &&
        preference.reservationTime.trim().isNotEmpty) {
      badges.add(
        _PreferenceBadge(
          icon: Icons.event_available_outlined,
          label: '${preference.reservationTime} 予約',
          foregroundColor: const Color(0xFF287A4B),
          backgroundColor: const Color(0xFFE8F5ED),
          borderColor: const Color(0xFFA5D6B7),
        ),
      );
    }

    if (facility.requiresParkExit) {
      badges.add(
        _PreferenceBadge(
          icon: Icons.directions_walk_outlined,
          label: facility.returnTravelMinutes > 0
              ? 'パーク外・再入園（往復移動 約${facility.outboundTravelMinutes + facility.returnTravelMinutes}分）'
              : 'パーク外・再入園',
          foregroundColor: const Color(0xFF6A3DA1),
          backgroundColor: const Color(0xFFF2EAFE),
          borderColor: const Color(0xFFC9AEEF),
        ),
      );
    }

    if (facility.supportsMobileOrder) {
      badges.add(
        const _PreferenceBadge(
          icon: Icons.phone_android_outlined,
          label: 'MO対応・食べたいフードがあるなら計画時に活用',
          foregroundColor: Color(0xFF287A4B),
          backgroundColor: Color(0xFFE8F5ED),
          borderColor: Color(0xFFA5D6B7),
        ),
      );
    }

    if (preference.fixedTimeStatus == FixedTimeStatus.planned &&
        preference.scheduledAccessTime.trim().isNotEmpty) {
      badges.add(
        _PreferenceBadge(
          icon: Icons.auto_fix_high_outlined,
          label: '${preference.scheduledAccessTime} 空き時間で追加',
          foregroundColor: const Color(0xFF4F378B),
          backgroundColor: const Color(0xFFF1ECFF),
          borderColor: const Color(0xFFC8B8F8),
        ),
      );
    }

    final accessBadge = _accessMethodBadge(
      facility: facility,
      preference: preference,
    );

    if (accessBadge != null) {
      badges.add(accessBadge);
    }

    return badges;
  }

  Widget? _accessMethodBadge({
    required Facility facility,
    required PlanPreference preference,
  }) {
    return switch (preference.accessMethod) {
      FacilityAccessMethod.standby => null,
      FacilityAccessMethod.dpa =>
        facility.supportsDpa
            ? const _PreferenceBadge(
                icon: Icons.bolt,
                label: 'DPA',
                foregroundColor: Color(0xFF0277BD),
                backgroundColor: Color(0xFFE3F2FD),
                borderColor: Color(0xFF90CAF9),
              )
            : null,
      FacilityAccessMethod.priorityPass => null,
      FacilityAccessMethod.standbyPass =>
        facility.supportsStandbyPass
            ? const _PreferenceBadge(
                icon: Icons.airplane_ticket_outlined,
                label: 'スタンバイパス',
                foregroundColor: Color(0xFF8A6D00),
                backgroundColor: Color(0xFFFFF8E1),
                borderColor: Color(0xFFFFD54F),
              )
            : null,
      FacilityAccessMethod.entryRequest =>
        facility.requiresEntryRequest
            ? const _PreferenceBadge(
                icon: Icons.how_to_reg_outlined,
                label: 'エントリー受付',
                foregroundColor: Color(0xFFEF6C00),
                backgroundColor: Color(0xFFFFF3E0),
                borderColor: Color(0xFFFFB74D),
              )
            : null,
      FacilityAccessMethod.reservation =>
        _supportsReservation(facility)
            ? const _PreferenceBadge(
                icon: Icons.event_available_outlined,
                label: '予約利用',
                foregroundColor: Color(0xFF287A4B),
                backgroundColor: Color(0xFFE8F5ED),
                borderColor: Color(0xFFA5D6B7),
              )
            : null,
      FacilityAccessMethod.freeSeating =>
        _isShowOrParade(facility)
            ? const _PreferenceBadge(
                icon: Icons.chair_alt_outlined,
                label: '自由席・自由鑑賞',
                foregroundColor: Color(0xFF514F66),
                backgroundColor: Color(0xFFF7F5FC),
                borderColor: Color(0xFFD5D0E0),
              )
            : null,
    };
  }

  bool _shouldShowLotteryFallback({
    required Facility? facility,
    required PlanPreference? preference,
  }) {
    if (facility == null || preference == null) {
      return false;
    }

    return facility.requiresEntryRequest &&
        preference.accessMethod == FacilityAccessMethod.entryRequest;
  }

  bool _supportsReservation(Facility facility) {
    // レストランという理由だけでは予約可能とみなさない。
    // 施設マスタで予約・PS対応が明示されている施設だけを対象にする。
    return facility.supportsReservationAccess;
  }

  bool _isShowOrParade(Facility facility) {
    return facility.category == FacilityCategory.show ||
        facility.category == FacilityCategory.parade;
  }

  _ScheduleItemVisualStyle _scheduleItemStyle(String typeName) {
    return switch (typeName) {
      'facility' => const _ScheduleItemVisualStyle(
        icon: Icons.place_outlined,
        color: Color(0xFF2457A6),
        backgroundColor: Color(0xFFEAF2FF),
      ),
      'breakfast' => const _ScheduleItemVisualStyle(
        icon: Icons.free_breakfast_outlined,
        color: Color(0xFF287A4B),
        backgroundColor: Color(0xFFE8F5ED),
      ),
      'lunch' => const _ScheduleItemVisualStyle(
        icon: Icons.lunch_dining_outlined,
        color: Color(0xFF287A4B),
        backgroundColor: Color(0xFFE8F5ED),
      ),
      'dinner' => const _ScheduleItemVisualStyle(
        icon: Icons.dinner_dining_outlined,
        color: Color(0xFF287A4B),
        backgroundColor: Color(0xFFE8F5ED),
      ),
      'breakTime' => const _ScheduleItemVisualStyle(
        icon: Icons.chair_outlined,
        color: Color(0xFF7A5B16),
        backgroundColor: Color(0xFFFFF8DF),
      ),
      'entry' => const _ScheduleItemVisualStyle(
        icon: Icons.login_outlined,
        color: Color(0xFF167B82),
        backgroundColor: Color(0xFFE4F5F5),
      ),
      'exit' => const _ScheduleItemVisualStyle(
        icon: Icons.logout_outlined,
        color: Color(0xFF536873),
        backgroundColor: Color(0xFFEDF3F5),
      ),
      _ => const _ScheduleItemVisualStyle(
        icon: Icons.event_outlined,
        color: Color(0xFF514F66),
        backgroundColor: Color(0xFFF7F5FC),
      ),
    };
  }
}

class _ScheduleTypeBadge extends StatelessWidget {
  const _ScheduleTypeBadge({required this.item, required this.style});

  final ScheduleItem item;
  final _ScheduleItemVisualStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.color),
          const SizedBox(width: 4),
          Text(
            item.type.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: style.color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCategoryBadge extends StatelessWidget {
  const _TimelineCategoryBadge({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final style = FacilityVisualStyle.categoryStyle(facility);

    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.foregroundColor),
          const SizedBox(width: 5),
          Text(
            style.label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: style.foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineAreaBadge extends StatelessWidget {
  const _TimelineAreaBadge({required this.areaId});

  final String areaId;

  @override
  Widget build(BuildContext context) {
    final style = FacilityVisualStyle.areaStyle(areaId);

    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.foregroundColor),
          const SizedBox(width: 5),
          Text(
            style.label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: style.foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceBadge extends StatelessWidget {
  const _PreferenceBadge({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LotteryFallbackInformation extends StatelessWidget {
  const _LotteryFallbackInformation({required this.action});

  final LotteryFallbackAction action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.alt_route_outlined,
            size: 17,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '外れた場合：${action.label}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleItemDetails extends StatelessWidget {
  const _ScheduleItemDetails({required this.item});

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final reason = item.reason?.trim();
    final note = item.note?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reason != null && reason.isNotEmpty)
            _ScheduleDetailRow(
              icon: Icons.lightbulb_outline,
              title: 'AI配置理由',
              content: reason,
            ),
          if (reason != null &&
              reason.isNotEmpty &&
              note != null &&
              note.isNotEmpty)
            const SizedBox(height: 8),
          if (note != null && note.isNotEmpty)
            _ScheduleDetailRow(
              icon: Icons.note_outlined,
              title: '施設メモ',
              content: note,
            ),
        ],
      ),
    );
  }
}

class _ScheduleDetailRow extends StatelessWidget {
  const _ScheduleDetailRow({
    required this.icon,
    required this.title,
    required this.content,
  });

  final IconData icon;
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 7),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$title：',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: content),
              ],
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}


class _PlanAdditionPickerSheet extends StatefulWidget {
  const _PlanAdditionPickerSheet({required this.choices});
  final List<PlanAdditionChoice> choices;

  @override
  State<_PlanAdditionPickerSheet> createState() =>
      _PlanAdditionPickerSheetState();
}

class _PlanAdditionPickerSheetState extends State<_PlanAdditionPickerSheet> {
  _FreeTimeCategoryFilter _filter = _FreeTimeCategoryFilter.all;

  bool _matches(PlanAdditionChoice choice) {
    switch (_filter) {
      case _FreeTimeCategoryFilter.all:
        return true;
      case _FreeTimeCategoryFilter.attraction:
        return choice.facility.category == FacilityCategory.attraction;
      case _FreeTimeCategoryFilter.performance:
        return choice.facility.category == FacilityCategory.show ||
            choice.facility.category == FacilityCategory.parade;
      case _FreeTimeCategoryFilter.greeting:
        return choice.facility.category == FacilityCategory.greeting;
      case _FreeTimeCategoryFilter.restaurant:
        return choice.facility.category == FacilityCategory.restaurant;
      case _FreeTimeCategoryFilter.shop:
        return choice.facility.category == FacilityCategory.shop;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.choices
        .where(_matches)
        .where((choice) => choice.inPlanCount == 0 || choice.repeatAllowed)
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('追加したいものを選ぶ'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: '閉じる',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
        children: [
          Text(
            'アトラクション、ショー・パレード、グリーティング、レストラン、ショップから選べます。'
            '選択後に一日全体を再計算し、現在の希望を維持できる場合だけ追加します。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'すでにプランにある施設でも、もう一度体験できるものは'
            '「プラン内 ○回・もう1回」と表示します。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final filter in _FreeTimeCategoryFilter.values)
                ChoiceChip(
                  label: Text(filter.label),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final choice in visible)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => Navigator.of(context).pop(choice),
                title: Text(
                  choice.facility.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${choice.inPlanCount > 0 ? 'プラン内 ${choice.inPlanCount}回 ・ ' : ''}'
                  '使用目安 ${_planDurationLabel(choice.estimatedMinutes)}'
                  '${choice.estimatedWaitMinutes > 0 ? '（待ち約${choice.estimatedWaitMinutes}分）' : ''}'
                  '${choice.spotlightReason == null ? '' : '\n今注目: ${choice.spotlightReason}'}',
                ),
                trailing: choice.inPlanCount > 0
                    ? Chip(label: Text(choice.repeatLabel))
                    : const Icon(Icons.add_circle_outline),
              ),
            ),
        ],
      ),
    );
  }
}

class _FreeTimeImprovementSheet extends StatefulWidget {
  const _FreeTimeImprovementSheet({
    required this.freeTimeItem,
    required this.choices,
    required this.previousTitle,
    required this.nextTitle,
  });

  final ScheduleItem freeTimeItem;
  final List<FreeTimeImprovementChoice> choices;
  final String? previousTitle;
  final String? nextTitle;

  @override
  State<_FreeTimeImprovementSheet> createState() =>
      _FreeTimeImprovementSheetState();
}

enum _FreeTimeCategoryFilter {
  all('おまかせ'),
  attraction('アトラクション'),
  performance('ショー・パレード'),
  greeting('グリーティング'),
  restaurant('レストラン'),
  shop('ショップ');

  const _FreeTimeCategoryFilter(this.label);
  final String label;
}

class _FreeTimeImprovementSheetState extends State<_FreeTimeImprovementSheet> {
  bool _showAllNewRecommendations = false;
  _FreeTimeCategoryFilter _categoryFilter = _FreeTimeCategoryFilter.all;

  bool _matchesCategory(FreeTimeImprovementChoice choice) {
    switch (_categoryFilter) {
      case _FreeTimeCategoryFilter.all:
        return true;
      case _FreeTimeCategoryFilter.attraction:
        return choice.facility.category == FacilityCategory.attraction;
      case _FreeTimeCategoryFilter.performance:
        return choice.kind == FreeTimeImprovementKind.performance;
      case _FreeTimeCategoryFilter.greeting:
        return choice.facility.category == FacilityCategory.greeting;
      case _FreeTimeCategoryFilter.restaurant:
        return choice.facility.category == FacilityCategory.restaurant;
      case _FreeTimeCategoryFilter.shop:
        return choice.facility.category == FacilityCategory.shop;
    }
  }

  String get _gapDurationLabel {
    final hours = _gapMinutes ~/ 60;
    final minutes = _gapMinutes % 60;
    if (hours == 0) return '$minutes分';
    if (minutes == 0) return '$hours時間';
    return '$hours時間$minutes分';
  }

  int get _gapMinutes {
    final start = widget.freeTimeItem.startHour * 60 +
        widget.freeTimeItem.startMinute;
    final end = widget.freeTimeItem.endHour * 60 + widget.freeTimeItem.endMinute;
    return end - start;
  }

  List<FreeTimeImprovementChoice> _sorted(
    Iterable<FreeTimeImprovementChoice> source,
  ) {
    final values = source.toList(growable: false);
    values.sort((left, right) {
      final scoreCompare = right.score.compareTo(left.score);
      if (scoreCompare != 0) return scoreCompare;
      return left.plannedStartMinutes.compareTo(right.plannedStartMinutes);
    });
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final wishlisted = _sorted(
      widget.choices.where(
        (choice) =>
            _matchesCategory(choice) &&
            choice.kind == FreeTimeImprovementKind.facility &&
            choice.alreadySelected,
      ),
    );
    final repeats = _sorted(
      widget.choices.where(
        (choice) => _matchesCategory(choice) && choice.kind == FreeTimeImprovementKind.repeatAttraction,
      ),
    );
    final performances = _sorted(
      widget.choices.where(
        (choice) => _matchesCategory(choice) && choice.kind == FreeTimeImprovementKind.performance,
      ),
    );
    final newRecommendations = _sorted(
      widget.choices.where(
        (choice) =>
            _matchesCategory(choice) &&
            choice.kind == FreeTimeImprovementKind.facility &&
            !choice.alreadySelected,
      ),
    );

    final visibleNewRecommendations = _showAllNewRecommendations
        ? newRecommendations
        : newRecommendations.take(3).toList(growable: false);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$_gapDurationLabelの使い方を提案',
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: '閉じる',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '使える時間：$_gapDurationLabel',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                if (widget.previousTitle != null)
                  Text('前の予定：${widget.previousTitle}'),
                if (widget.nextTitle != null)
                  Text('次の予定：${widget.nextTitle}'),
                const SizedBox(height: 8),
                const Text(
                  'この時間量を予算として、前後の予定・移動・営業時間を守れる使い方を提案します。'
                  'カテゴリを選んでも時刻を直接指定する必要はありません。候補は自動追加されません。',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '何に使いたいですか？',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in _FreeTimeCategoryFilter.values)
                ChoiceChip(
                  label: Text(filter.label),
                  selected: _categoryFilter == filter,
                  onSelected: (_) => setState(() {
                    _categoryFilter = filter;
                    _showAllNewRecommendations = false;
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          Text(
            'やりたいことからおすすめ',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '登録済みで、まだ予定に入っていない施設を最優先で表示します。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 7),
          if (wishlisted.isEmpty)
            _FreeTimeEmptySection(
              icon: Icons.favorite_border,
              message: 'この空き時間に安全に入る未実施の「やりたいこと」はありません。',
            )
          else
            for (var index = 0; index < wishlisted.length; index++)
              _FreeTimeImprovementChoiceTile(
                choice: wishlisted[index],
                rank: index + 1,
                emphasized: index == 0,
              ),

          if (repeats.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'もう一度乗る（乗り放題）',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'すでに予定に入っている乗り放題対象アトラクションです。'
              'Disney Plannerは自動では追加しません。'
              'もう一度乗りたい施設だけ、ユーザーが選んで追加できます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 7),
            for (var index = 0; index < repeats.length; index++)
              _FreeTimeImprovementChoiceTile(
                choice: repeats[index],
                rank: index + 1,
              ),
          ],

          if (performances.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'ショー・パレード',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'この時間枠に収まる公演です。エントリー受付やDPA対象公演は、'
              '当選・購入済みの場合だけ追加してください。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 7),
            for (var index = 0; index < performances.length; index++)
              _FreeTimeImprovementChoiceTile(
                choice: performances[index],
                rank: index + 1,
              ),
          ],

          if (newRecommendations.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              '新しいおすすめ',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '「やりたいこと」には未登録の候補です。'
              'マスタ上の人気度は参考程度にとどめ、体験価値・待ち時間・移動・空き時間の有効活用を総合評価します。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 7),
            for (var index = 0;
                index < visibleNewRecommendations.length;
                index++)
              _FreeTimeImprovementChoiceTile(
                choice: visibleNewRecommendations[index],
                rank: index + 1,
                emphasized: wishlisted.isEmpty &&
                    repeats.isEmpty &&
                    performances.isEmpty &&
                    index == 0,
              ),
            if (newRecommendations.length > 3) ...[
              const SizedBox(height: 2),
              OutlinedButton.icon(
                onPressed: () => setState(
                  () => _showAllNewRecommendations =
                      !_showAllNewRecommendations,
                ),
                icon: Icon(
                  _showAllNewRecommendations
                      ? Icons.expand_less
                      : Icons.expand_more,
                ),
                label: Text(
                  _showAllNewRecommendations
                      ? '新しいおすすめを閉じる'
                      : 'その他の新しいおすすめを表示（${newRecommendations.length - 3}件）',
                ),
              ),
            ],
          ],

          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '乗り放題対象の再乗車は「もう一度乗る」から手動で追加できます。'
              'Disney Plannerが勝手に2回目・3回目を追加することはありません。'
              '1件追加したあとも空き時間が20分以上残れば、残り時間を続けて改善できます。',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.free_breakfast_outlined),
            label: const Text('このまま休憩・自由時間にする'),
          ),
        ],
      ),
    );
  }
}

class _FreeTimeEmptySection extends StatelessWidget {
  const _FreeTimeEmptySection({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeTimeImprovementChoiceTile extends StatelessWidget {
  const _FreeTimeImprovementChoiceTile({
    required this.choice,
    required this.rank,
    this.emphasized = false,
  });

  final FreeTimeImprovementChoice choice;
  final int rank;
  final bool emphasized;

  String _recommendationReason() {
    final totalMovement = choice.movementInMinutes + choice.movementOutMinutes;
    final wait = choice.estimatedWaitMinutes;
    if (choice.kind == FreeTimeImprovementKind.repeatAttraction) {
      final repeatNumber = choice.repeatNumber ?? 2;
      return 'すでに予定にある乗り放題対象です。選んだ場合だけ$repeatNumber回目として手動追加します。';
    }
    if (choice.alreadySelected) {
      return 'やりたいことに登録済みで、この空き時間に安全に収まります。';
    }
    if (choice.kind == FreeTimeImprovementKind.performance) {
      return 'この時間枠で鑑賞でき、前後の予定にも間に合う公演です。';
    }
    if (choice.facility.category == FacilityCategory.restaurant) {
      return 'この時間予算と前後の移動に収まるレストランです。予約必須施設は候補から除外しています。';
    }
    if (choice.facility.category == FacilityCategory.shop) {
      return 'この時間予算と前後の動線に収まりやすいショップです。滞在時間を含めて評価しています。';
    }
    if (choice.facility.category == FacilityCategory.greeting) {
      return '未登録のグリーティング候補です。カテゴリだけでは優先せず、体験価値・待ち時間・移動・空き枠活用を総合評価しています。';
    }
    if (!choice.alreadySelected && choice.expertScore >= 75) {
      return '体験価値が高く、空き時間を有効に使える新しいおすすめです。';
    }
    if (choice.fitSlackMinutes <= 30) {
      return '前後の予定を守りながら、空き時間を無駄なく使える候補です。';
    }
    if (totalMovement <= 10) {
      return '前後の移動が少なく、空き時間を効率よく使える候補です。';
    }
    if (wait != null && wait <= 15) {
      return '待ち時間は短めですが、短さだけでなく体験価値と空き枠活用も含めて評価しています。';
    }
    return '体験価値・待ち時間・前後の移動・空き枠の使い切りやすさを総合評価した候補です。';
  }

  @override
  Widget build(BuildContext context) {
    final isPerformance = choice.kind == FreeTimeImprovementKind.performance;
    final isRepeat =
        choice.kind == FreeTimeImprovementKind.repeatAttraction;
    final wait = choice.estimatedWaitMinutes;
    final colorScheme = Theme.of(context).colorScheme;
    final kindLabel = isRepeat
        ? 'もう一度乗る'
        : isPerformance
            ? choice.facility.category == FacilityCategory.parade
                ? 'パレード'
                : 'ショー'
            : choice.facility.category == FacilityCategory.greeting
                ? 'グリーティング'
                : choice.facility.category == FacilityCategory.restaurant
                    ? 'レストラン'
                    : choice.facility.category == FacilityCategory.shop
                        ? 'ショップ'
                        : 'アトラクション';

    return Card(
      margin: const EdgeInsets.only(bottom: 7),
      color: emphasized ? colorScheme.primaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).pop(choice),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                child: Icon(
                  isPerformance
                      ? choice.facility.category == FacilityCategory.parade
                          ? Icons.celebration_outlined
                          : Icons.theater_comedy_outlined
                      : choice.facility.category == FacilityCategory.greeting
                          ? Icons.people_alt_outlined
                          : choice.facility.category == FacilityCategory.restaurant
                              ? Icons.restaurant_outlined
                              : choice.facility.category == FacilityCategory.shop
                                  ? Icons.shopping_bag_outlined
                                  : Icons.attractions_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '$rank位',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            kindLabel,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        if (choice.alreadySelected && !isRepeat)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'やりたいこと',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        if (isRepeat)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${choice.repeatNumber ?? 2}回目として追加',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      choice.facility.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isPerformance
                          ? '${choice.plannedStartLabel}開演・約${choice.facility.durationMinutes}分・${choice.preparationMinutes}分前準備'
                          : '${choice.plannedStartLabel}〜${choice.plannedEndLabel}${wait == null ? '' : '・予測待ち約$wait分'}',
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '前から${choice.movementInMinutes}分 ／ 次へ${choice.movementOutMinutes}分'
                      '${choice.fitSlackMinutes > 0 ? ' ／ 追加後の余白 約${choice.fitSlackMinutes}分' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _recommendationReason(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: emphasized
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                    ),
                    if (!isPerformance && choice.expertScore > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Disney通おすすめ評価 ${choice.expertScore.toStringAsFixed(1)}点'
                        '${choice.expertReason == null || choice.expertReason!.trim().isEmpty ? '' : '（${choice.expertReason}）'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    if (!isPerformance && choice.waitSource != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        choice.waitSource!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleItemVisualStyle {
  const _ScheduleItemVisualStyle({
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;
}

class _PlanTextExportDialog extends StatefulWidget {
  const _PlanTextExportDialog({
    required this.simpleText,
    required this.evaluationText,
  });

  final String simpleText;
  final String evaluationText;

  @override
  State<_PlanTextExportDialog> createState() => _PlanTextExportDialogState();
}

class _PlanTextExportDialogState extends State<_PlanTextExportDialog> {
  final ScrollController _scrollController = ScrollController();
  PlanTextExportFormat _format = PlanTextExportFormat.simple;

  String get _text => switch (_format) {
    PlanTextExportFormat.simple => widget.simpleText,
    PlanTextExportFormat.evaluation => widget.evaluationText,
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _text));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('プラン文章をコピーしました。')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return AlertDialog(
      title: const Text('プランを文章で出力'),
      content: SizedBox(
        width: size.width < 700 ? size.width : 680,
        height: size.height * 0.65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<PlanTextExportFormat>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: PlanTextExportFormat.simple,
                  icon: Icon(Icons.short_text),
                  label: Text('簡易版'),
                ),
                ButtonSegment(
                  value: PlanTextExportFormat.evaluation,
                  icon: Icon(Icons.analytics_outlined),
                  label: Text('AI評価用'),
                ),
              ],
              selected: {_format},
              onSelectionChanged: (values) {
                setState(() => _format = values.first);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  interactive: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: SelectableText(
                      _text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
        FilledButton.icon(
          onPressed: _copy,
          icon: const Icon(Icons.copy),
          label: const Text('コピー'),
        ),
      ],
    );
  }
}
