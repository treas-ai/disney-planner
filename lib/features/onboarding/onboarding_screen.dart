import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../data/local/planner_experience_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onCompleted});

  final Future<void> Function(PlannerExperienceMode mode) onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;
  PlannerExperienceMode _mode = PlannerExperienceMode.beginner;

  static const _pages = [
    (
      Icons.auto_awesome,
      'やりたいことから一日を組み立てます',
      '乗りたい・見たい・食べたいものを選ぶと、待ち時間や移動を考えて一日の順番を作ります。',
    ),
    (
      Icons.lock_clock_outlined,
      '予約や公演時刻は動かしません',
      '予約済みレストラン、ショー、パレードなどの確定時刻を守りながら、前後の予定を調整します。',
    ),
    (
      Icons.event_available_outlined,
      '当日は状況に合わせて組み直せます',
      '休憩したいときや予定が変わったときは、当日ガイドから残りの予定を調整できます。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isModePage = _index == _pages.length;
    final last = isModePage;
    final pageCount = _pages.length + 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pageCount,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) {
                  if (index == _pages.length) {
                    return _ModeChoice(
                      mode: _mode,
                      onChanged: (mode) => setState(() => _mode = mode),
                    );
                  }
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
                  Text('${_index + 1}/$pageCount'),
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      if (last) {
                        await widget.onCompleted(_mode);
                        return;
                      }
                      await _controller.nextPage(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      );
                    },
                    child: Text(last ? 'このモードではじめる' : '次へ'),
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

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({required this.mode, required this.onChanged});

  final PlannerExperienceMode mode;
  final ValueChanged<PlannerExperienceMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            children: [
              const Icon(Icons.route_outlined, size: 72),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '使い方を選んでください',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'あとから初回案内をやり直せます。プラン作成機能そのものはどちらも同じです。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              _ModeTile(
                selected: mode == PlannerExperienceMode.beginner,
                icon: Icons.auto_awesome_outlined,
                title: 'はじめてでもおまかせ',
                description: '次にやることを画面で案内します。まずはこちらがおすすめです。',
                onTap: () => onChanged(PlannerExperienceMode.beginner),
              ),
              const SizedBox(height: AppSpacing.md),
              _ModeTile(
                selected: mode == PlannerExperienceMode.detailed,
                icon: Icons.tune_outlined,
                title: '細かく自分で設定',
                description: '今までどおり各画面を自由に移動し、細かな条件まで自分で設定します。',
                onTap: () => onChanged(PlannerExperienceMode.detailed),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(icon, size: 34),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(description),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(selected ? Icons.check_circle : Icons.circle_outlined),
            ],
          ),
        ),
      ),
    );
  }
}
