import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/enums/facility_category.dart';

class FacilityCategoryFilter extends StatelessWidget {
  const FacilityCategoryFilter({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
  });

  final FacilityCategory? selectedCategory;
  final ValueChanged<FacilityCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: const Text('すべて'),
                selected: selectedCategory == null,
                onSelected: (_) => onSelected(null),
              ),
            ),
            for (final category in FacilityCategory.values)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: ChoiceChip(
                  label: Text(category.label),
                  selected: selectedCategory == category,
                  onSelected: (_) => onSelected(category),
                ),
              ),
          ],
        ),
      ),
    );
  }
}