import 'package:flutter/material.dart';

import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
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
    _controller ??= AssistantController(AppStateScope.of(context));
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
