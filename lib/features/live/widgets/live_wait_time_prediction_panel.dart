import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/facility.dart';
import '../../../domain/entities/wait_time_prediction.dart';
import '../../../domain/enums/facility_category.dart';
import '../live_controller.dart';

class LiveWaitTimePredictionPanel extends StatelessWidget {
  const LiveWaitTimePredictionPanel({super.key, required this.controller});

  final LiveController controller;

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries();
    if (entries.isEmpty && !controller.predictionController.isLoading) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI待ち時間予測',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (controller.predictionController.isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '手入力した現在値と蓄積履歴を使った参考予測です。公式の待ち時間ではありません。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (var index = 0; index < entries.length; index++) ...[
              _PredictionRow(entry: entries[index]),
              if (index < entries.length - 1)
                const Divider(height: AppSpacing.lg),
            ],
          ],
        ],
      ),
    );
  }

  List<_PredictionEntry> _buildEntries() {
    final schedule = controller.schedule;
    if (schedule == null || !controller.scheduleMatchesCurrentPark) {
      return const [];
    }

    final facilities = <String, Facility>{};
    for (final item in schedule.items) {
      final facility = controller.facilityById(item.facilityId);
      if (facility == null ||
          facility.category != FacilityCategory.attraction) {
        continue;
      }
      facilities[facility.id] = facility;
    }

    final entries = <_PredictionEntry>[];
    for (final facility in facilities.values) {
      final prediction = controller.predictionController.predictionForFacility(
        facility.id,
      );
      if (prediction == null) {
        continue;
      }
      entries.add(_PredictionEntry(facility: facility, prediction: prediction));
    }

    entries.sort((left, right) {
      final leftMinutes = left.prediction.predictedMinutes ?? 9999;
      final rightMinutes = right.prediction.predictedMinutes ?? 9999;
      return leftMinutes.compareTo(rightMinutes);
    });

    return List<_PredictionEntry>.unmodifiable(entries.take(5));
  }
}

class _PredictionRow extends StatelessWidget {
  const _PredictionRow({required this.entry});

  final _PredictionEntry entry;

  @override
  Widget build(BuildContext context) {
    final prediction = entry.prediction;
    final colorScheme = Theme.of(context).colorScheme;
    final target = prediction.targetTime.toLocal();
    final timeLabel =
        '${target.hour.toString().padLeft(2, '0')}:'
        '${target.minute.toString().padLeft(2, '0')}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.facility.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                prediction.reasons.isEmpty
                    ? '予測根拠なし'
                    : prediction.reasons.first,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$timeLabel予測',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              prediction.rangeLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: prediction.isAvailable
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '信頼度 ${prediction.confidence.label}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _PredictionEntry {
  const _PredictionEntry({required this.facility, required this.prediction});

  final Facility facility;
  final WaitTimePrediction prediction;
}
