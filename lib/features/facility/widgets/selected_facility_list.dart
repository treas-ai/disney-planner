import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/facility.dart';

class SelectedFacilityList extends StatelessWidget {
  const SelectedFacilityList({
    super.key,
    required this.selectedFacilities,
    required this.onRemove,
  });

  final List<Facility> selectedFacilities;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (selectedFacilities.isEmpty) {
      return AppCard(
        child: Text(
          'まだ施設が選択されていません。',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('選択済み施設', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          for (final facility in selectedFacilities)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(facility.name, overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    tooltip: '削除',
                    onPressed: () => onRemove(facility.id),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
