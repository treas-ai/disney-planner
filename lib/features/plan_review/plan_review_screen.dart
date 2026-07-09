import 'package:flutter/material.dart';

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
  late final ScheduleController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScheduleController();
    _controller.addListener(_refresh);
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Builder(
        builder: (context) {
          if (_controller.isLoading) {
            return const LoadingView(message: 'スケジュールを生成中です...');
          }

          if (_controller.errorMessage != null) {
            return EmptyState(
              title: '生成エラー',
              message: _controller.errorMessage!,
              icon: Icons.error_outline,
            );
          }

          return ListView(
            children: [
              const SectionTitle(
                title: 'プラン確認',
                subtitle: 'AIなしの簡易スケジュールを生成します。',
                icon: AppIcons.planReviewSelected,
              ),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schedule Engine v1',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      '現在はデモデータを使用して、優先度・希望時間・食事設定をもとに予定を並べます。',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'スケジュール生成',
                      icon: Icons.auto_awesome,
                      onPressed: _controller.generateDemoSchedule,
                    ),
                  ],
                ),
              ),
              if (_controller.schedule == null)
                const EmptyState(
                  title: 'スケジュール未生成',
                  message: 'ボタンを押すと、デモデータから1日の予定を作成します。',
                )
              else
                _ScheduleResult(schedule: _controller.schedule!),
            ],
          );
        },
      ),
    );
  }
}

class _ScheduleResult extends StatelessWidget {
  const _ScheduleResult({
    required this.schedule,
  });

  final DaySchedule schedule;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '生成結果',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final item in schedule.items) _ScheduleItemTile(item: item),
        ],
      ),
    );
  }
}

class _ScheduleItemTile extends StatelessWidget {
  const _ScheduleItemTile({
    required this.item,
  });

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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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