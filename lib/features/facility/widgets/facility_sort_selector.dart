import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../facility_sort_type.dart';

class FacilitySortSelector extends StatelessWidget {
  const FacilitySortSelector({
    super.key,
    required this.selectedSortType,
    required this.onSelected,
  });

  final FacilitySortType selectedSortType;
  final ValueChanged<FacilitySortType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sort_outlined, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Text('並び順', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 620) {
                return _WideSortSelector(
                  selectedSortType: selectedSortType,
                  onSelected: onSelected,
                );
              }

              return _CompactSortSelector(
                selectedSortType: selectedSortType,
                onSelected: onSelected,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WideSortSelector extends StatelessWidget {
  const _WideSortSelector({
    required this.selectedSortType,
    required this.onSelected,
  });

  final FacilitySortType selectedSortType;
  final ValueChanged<FacilitySortType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final sortType in FacilitySortType.values)
          _SortChoiceChip(
            sortType: sortType,
            selected: selectedSortType == sortType,
            onSelected: () {
              onSelected(sortType);
            },
          ),
      ],
    );
  }
}

class _CompactSortSelector extends StatelessWidget {
  const _CompactSortSelector({
    required this.selectedSortType,
    required this.onSelected,
  });

  final FacilitySortType selectedSortType;
  final ValueChanged<FacilitySortType> onSelected;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<FacilitySortType>(
      key: ValueKey(selectedSortType),
      initialValue: selectedSortType,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '施設の並び順',
        prefixIcon: Icon(Icons.sort_outlined),
        border: OutlineInputBorder(),
      ),
      items: FacilitySortType.values
          .map((sortType) {
            return DropdownMenuItem<FacilitySortType>(
              value: sortType,
              child: Row(
                children: [
                  Icon(_sortIcon(sortType), size: 18),
                  const SizedBox(width: 8),
                  Text(sortType.label),
                ],
              ),
            );
          })
          .toList(growable: false),
      onChanged: (sortType) {
        if (sortType == null) {
          return;
        }

        onSelected(sortType);
      },
    );
  }
}

class _SortChoiceChip extends StatelessWidget {
  const _SortChoiceChip({
    required this.sortType,
    required this.selected,
    required this.onSelected,
  });

  final FacilitySortType sortType;
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
              _sortIcon(sortType),
              size: 17,
              color: colorScheme.onSurfaceVariant,
            ),
      label: Text(sortType.label, maxLines: 1, softWrap: false),
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

IconData _sortIcon(FacilitySortType sortType) {
  return switch (sortType) {
    FacilitySortType.areaOrder => Icons.map_outlined,
    FacilitySortType.nameOrder => Icons.sort_by_alpha_outlined,
    FacilitySortType.categoryOrder => Icons.category_outlined,
    FacilitySortType.operatingStatusOrder => Icons.check_circle_outline,
    FacilitySortType.selectedFirst => Icons.playlist_add_check_outlined,
  };
}
