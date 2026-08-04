import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../domain/entities/assistant_insight.dart';
import '../../domain/entities/live_operation_snapshot.dart';
import '../live_data/manual_live_data_screen.dart';
import 'assistant_controller.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  static const _suggestions = [
    '今どこへ行けばいい？',
    '昼食はいつがおすすめ？',
    'ショーまで何をすればいい？',
    '今日は混んでる？',
    '休憩を入れた方がいい？',
  ];

  final TextEditingController _textController = TextEditingController();
  AssistantController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      final controller = AssistantController(AppStateScope.of(context));
      _controller = controller;
      unawaited(controller.loadLiveOperation());
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _ask([String? question]) async {
    final text = question ?? _textController.text;
    if (text.trim().isEmpty) {
      return;
    }
    _textController.text = text;
    await _controller!.ask(text);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (controller.liveOperation != null) ...[
              _LiveOperationCard(
                snapshot: controller.liveOperation!,
                onManualInput: () async {
                  final parkId =
                      AppStateScope.of(context).daySchedule?.parkId ??
                      AppStateScope.of(context).tripSettings.parkId;
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ManualLiveDataScreen(parkId: parkId),
                    ),
                  );
                  await controller.loadLiveOperation();
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AIコンシェルジュ',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '現在のプランをもとに、次の行動を案内します。チケット、予約、公式待ち時間、運営情報は公式アプリを確認してください。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _textController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _ask(),
                    decoration: InputDecoration(
                      labelText: '質問を入力',
                      hintText: '例：今どこへ行けばいい？',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: '質問する',
                        onPressed: controller.isLoading ? null : _ask,
                        icon: const Icon(Icons.send_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final suggestion in _suggestions)
                        ActionChip(
                          label: Text(suggestion),
                          onPressed: controller.isLoading
                              ? null
                              : () => _ask(suggestion),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (controller.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (controller.errorMessage != null)
              AppCard(
                child: Text(
                  controller.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              )
            else if (controller.response != null)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.smart_toy_outlined),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '回答',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(controller.response!.message),
                    if (controller.response!.insight != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _IntelligenceSummary(
                        insight: controller.response!.insight!,
                      ),
                    ],
                    if (controller.response!.reasons.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '理由',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      for (final reason in controller.response!.reasons)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('・$reason'),
                        ),
                    ],
                  ],
                ),
              )
            else
              const AppCard(child: Text('質問候補を選ぶか、自由に質問を入力してください。')),
          ],
        );
      },
    );
  }
}

class _IntelligenceSummary extends StatelessWidget {
  const _IntelligenceSummary({required this.insight});

  final AssistantInsight insight;

  @override
  Widget build(BuildContext context) {
    final priority = insight.priority;
    final confidence = insight.confidence;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI判断',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('優先度 ${priority.label}')),
              Chip(label: Text('信頼度 ${confidence.label}')),
              Chip(label: Text('判断スコア ${insight.score}')),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(insight.description),
        ],
      ),
    );
  }
}

class _LiveOperationCard extends StatelessWidget {
  const _LiveOperationCard({
    required this.snapshot,
    required this.onManualInput,
  });

  final LiveOperationSnapshot snapshot;
  final VoidCallback onManualInput;

  String _formatUpdatedAt(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final park = snapshot.parkOperation;
    final weather = snapshot.weather;
    final crowd = snapshot.crowd;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_outlined),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '本日のパーク状況',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Chip(label: Text(snapshot.sourceLabel)),
              IconButton(
                tooltip: '待ち時間を手動入力',
                onPressed: onManualInput,
                icon: const Icon(Icons.edit_note_outlined),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (park != null)
                Chip(label: Text('営業時間 ${park.operatingHoursLabel}')),
              if (weather != null)
                Chip(label: Text('天気 ${weather.condition.label}')),
              if (weather?.temperatureCelsius != null)
                Chip(
                  label: Text(
                    '${weather!.temperatureCelsius!.toStringAsFixed(0)}℃',
                  ),
                ),
              if (crowd != null)
                Chip(label: Text('混雑 ${crowd.parkLevel.label}')),
            ],
          ),
          if (snapshot.attractions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '主要アトラクション（${snapshot.sourceLabel}）',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final attraction in snapshot.attractions.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '・${attraction.facilityId}：${attraction.availability.label}'
                  '${attraction.standbyMinutes == null ? '' : ' / ${attraction.standbyMinutes}分'}',
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            '最終更新 ${_formatUpdatedAt(snapshot.updatedAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (snapshot.fallbackMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              snapshot.fallbackMessage!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (snapshot.isMock) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '現在はサンプルデータを表示しています。実際の運営情報は公式アプリで確認してください。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
