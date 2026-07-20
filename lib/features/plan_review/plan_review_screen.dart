import 'package:flutter/material.dart';

import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/section_title.dart';
import '../../domain/entities/day_schedule.dart';
import '../../domain/entities/schedule_item.dart';
import 'schedule_controller.dart';

class PlanReviewScreen extends StatefulWidget {
  const PlanReviewScreen({super.key});

  @override
  State<PlanReviewScreen> createState() => _PlanReviewScreenState();
}

class _PlanReviewScreenState extends State<PlanReviewScreen> {
  ScheduleController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_controller == null) {
      final appState = AppStateScope.of(context);

      _controller = ScheduleController(appState);
      _controller!.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_refresh);
    _controller?.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller == null) {
      return const AppScaffold(child: LoadingView(message: 'プラン確認画面を準備中です...'));
    }

    return AppScaffold(
      child: Builder(
        builder: (context) {
          if (controller.isLoading) {
            return const LoadingView(message: 'スケジュールを生成中です...');
          }

          if (controller.errorMessage != null) {
            return EmptyState(
              title: '生成エラー',
              message: controller.errorMessage!,
              icon: Icons.error_outline,
            );
          }

          return ListView(
            children: [
              const SectionTitle(
                title: 'プラン確認',
                subtitle: '設定と選択済み施設から簡易スケジュールを生成します。',
                icon: AppIcons.planReviewSelected,
              ),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schedule Engine v1.1',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('設定画面の来園条件と、施設一覧で選択した施設・希望条件をもとに予定を作成します。'),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'スケジュール生成',
                            icon: Icons.auto_awesome,
                            onPressed: controller.generateSchedule,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppButton(
                            label: 'クリア',
                            icon: Icons.delete_outline,
                            onPressed: controller.clearSchedule,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!controller.canGenerateSchedule)
                const EmptyState(
                  title: '施設が選択されていません',
                  message: 'プラン編集タブで行きたい施設を追加してください。',
                )
              else if (controller.schedule == null)
                const EmptyState(
                  title: 'スケジュール未生成',
                  message: 'ボタンを押すと、選択済み施設から1日の予定を作成します。',
                )
              else
                _ScheduleResult(schedule: controller.schedule!),
            ],
          );
        },
      ),
    );
  }
}

class _ScheduleResult extends StatelessWidget {
  const _ScheduleResult({required this.schedule});

  final DaySchedule schedule;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('生成結果', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          for (final item in schedule.items) _ScheduleItemTile(item: item),
        ],
      ),
    );
  }
}

class _ScheduleItemTile extends StatelessWidget {
  const _ScheduleItemTile({required this.item});

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.timeRangeLabel,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${item.type.label}：${item.title}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (item.reason != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('理由：${item.reason}'),
          ],
          if (item.note != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('メモ：${item.note}'),
          ],
          const Divider(),
        ],
      ),
    );
  }
}
