import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/enums/facility_category.dart';
import 'facility_visual_style.dart';

class FacilityCategoryFilter extends StatelessWidget {
  const FacilityCategoryFilter({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
  });

  final FacilityCategory? selectedCategory;
  final ValueChanged<FacilityCategory?> onSelected;

  static List<FacilityCategory> get _visibleCategories {
    return FacilityCategory.values
        .where((category) => category != FacilityCategory.parade)
        .toList(growable: false);
  }

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
              child: _AllCategoryChip(
                selected: selectedCategory == null,
                onSelected: () {
                  onSelected(null);
                },
              ),
            ),
            for (final category in _visibleCategories)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _CategoryFilterChip(
                  category: category,
                  selected: selectedCategory == category,
                  onSelected: () {
                    onSelected(category);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AllCategoryChip extends StatelessWidget {
  const _AllCategoryChip({required this.selected, required this.onSelected});

  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      selected: selected,
      showCheckmark: selected,
      avatar: selected
          ? null
          : Icon(
              Icons.grid_view_outlined,
              size: 17,
              color: colorScheme.onSurfaceVariant,
            ),
      label: const Text('すべて', maxLines: 1, softWrap: false),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
      backgroundColor: colorScheme.surface,
      labelStyle: TextStyle(
        color: selected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected ? colorScheme.primary : colorScheme.outlineVariant,
        width: selected ? 1.5 : 1,
      ),
      onSelected: (_) {
        onSelected();
      },
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  final FacilityCategory category;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final style = FacilityVisualStyle.categoryStyleForCategory(category);

    final unselectedBackgroundColor = Color.alphaBlend(
      style.backgroundColor.withValues(alpha: 0.10),
      Theme.of(context).colorScheme.surface,
    );

    return FilterChip(
      selected: selected,
      showCheckmark: selected,
      avatar: selected
          ? null
          : Icon(style.icon, size: 17, color: style.backgroundColor),
      label: Text(style.label, maxLines: 1, softWrap: false),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      selectedColor: style.backgroundColor,
      checkmarkColor: style.foregroundColor,
      backgroundColor: unselectedBackgroundColor,
      labelStyle: TextStyle(
        color: selected ? style.foregroundColor : style.backgroundColor,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      ),
      side: BorderSide(color: style.backgroundColor, width: selected ? 1.5 : 1),
      onSelected: (_) {
        onSelected();
      },
    );
  }
}
