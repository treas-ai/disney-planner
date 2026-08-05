import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onCompleted});

  final Future<void> Function() onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const _pages = [
    (
      Icons.auto_awesome,
      '会話でやりたいことを決定',
      '質問に答えるだけでやりたいことを自動作成し、必要な店舗・施設を抽出します。',
    ),
    (
      Icons.lock_clock_outlined,
      '予約・公式公演時刻を固定',
      'ショー、パレード、予約、DPAなどの確定時刻は再計算しても動かしません。',
    ),
    (
      Icons.edit_note_outlined,
      '待ち時間を手動で反映',
      '公式アプリを確認し、必要な施設だけ入力してAI改善に利用できます。',
    ),
    (
      Icons.health_and_safety_outlined,
      '公式情報を最優先',
      'Disney Plannerは公式アプリの補助ツールです。最終確認は必ず公式情報で行ってください。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final last = _index == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(page.$1, size: 80),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          page.$2,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          page.$3,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Text('${_index + 1}/${_pages.length}'),
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      if (last) {
                        await widget.onCompleted();
                        return;
                      }
                      await _controller.nextPage(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      );
                    },
                    child: Text(last ? 'はじめる' : '次へ'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
