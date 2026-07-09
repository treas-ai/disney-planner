import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/facility.dart';

class FacilityCard extends StatelessWidget {
  const FacilityCard({
    super.key,
    required this.facility,
  });

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final waitTimeText = facility.waitTime == null
        ? '待ち時間：未取得'
        : '待ち時間：${facility.waitTime!.minutes}分';

    final reservationText = facility.reservation == null
        ? '予約：なし'
        : '予約：${facility.reservation!.type.label}';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            facility.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _InfoChip(label: facility.category.label),
              _InfoChip(label: facility.priority.stars),
              _InfoChip(label: waitTimeText),
              _InfoChip(label: reservationText),
            ],
          ),
          if (facility.description != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              facility.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}