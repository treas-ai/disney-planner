import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/plan_optimization_result.dart';

class PlanOptimizationSheet extends StatelessWidget {
  const PlanOptimizationSheet({
    super.key,
    required this.result,
    required this.onApply,
  });

  final PlanOptimizationResult result;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'プラン再最適化',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Score(label: '現在の評価', score: result.beforeScore),
                  Icon(Icons.arrow_forward, color: colorScheme.primary),
                  _Score(label: '再配置後', score: result.afterScore),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                result.hasImprovement
                    ? 'より効率のよい並び順が見つかりました。'
                    : '現在の条件では、並び替えによる明確な改善は見つかりませんでした。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '評価内訳',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final dimension in result.dimensions)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text('${dimension.score}'),
                        ),
                        title: Text(dimension.label),
                        subtitle: Text(dimension.message),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '再最適化の提案',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final recommendation in result.recommendations)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 18),
                            const SizedBox(width: 7),
                            Expanded(child: Text(recommendation)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      '評価指数はプランの良し悪しを100点満点で採点するものではなく、現在案と再配置案を同じ条件で比較するための指標です。待ち時間・移動・雨天・イベント影響・歩行負担をルールベースで再評価します。固定予定と食事予定は変更しません。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('変更しない'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: result.hasImprovement
                        ? () {
                            onApply();
                            Navigator.of(context).pop();
                          }
                        : null,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('再最適化案を反映'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          '評価指数 $score',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
