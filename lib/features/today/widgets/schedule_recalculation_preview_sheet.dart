import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/schedule_change.dart';
import '../../../domain/entities/schedule_recalculation_result.dart';
import '../../../domain/enums/schedule_change_type.dart';

Future<bool> showScheduleRecalculationPreviewSheet({
  required BuildContext context,
  required ScheduleRecalculationResult result,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => _PreviewSheet(result: result),
      ) ??
      false;
}

class _PreviewSheet extends StatelessWidget {
  const _PreviewSheet({required this.result});
  final ScheduleRecalculationResult result;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '再計算結果を確認',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text('この画面で「変更を反映」を押すまで現在の予定は変わりません。'),
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              ...result.warnings.map(
                (warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_outlined, size: 18),
                      const SizedBox(width: 6),
                      Expanded(child: Text(warning)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView.separated(
                controller: controller,
                itemCount: result.changes.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _ChangeTile(change: result.changes[index]),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('キャンセル'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.check),
                    label: const Text('変更を反映'),
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

class _ChangeTile extends StatelessWidget {
  const _ChangeTile({required this.change});
  final ScheduleChange change;

  @override
  Widget build(BuildContext context) {
    final icon = switch (change.type) {
      ScheduleChangeType.unchanged => Icons.lock_outline,
      ScheduleChangeType.moved => Icons.swap_vert,
      ScheduleChangeType.added => Icons.add_circle_outline,
      ScheduleChangeType.removed => Icons.remove_circle_outline,
    };
    final before = change.beforeItem?.timeRangeLabel;
    final after = change.afterItem?.timeRangeLabel;
    final timeText = switch (change.type) {
      ScheduleChangeType.moved => '$before → $after',
      ScheduleChangeType.added => after ?? '',
      ScheduleChangeType.removed => before ?? '',
      ScheduleChangeType.unchanged => after ?? before ?? '',
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(
        change.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('$timeText\n${change.reason}'),
      isThreeLine: true,
      trailing: Text(change.type.label),
    );
  }
}
