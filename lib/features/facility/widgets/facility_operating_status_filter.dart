import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../facility_operating_filter.dart';

class FacilityOperatingStatusFilter extends StatelessWidget {
  const FacilityOperatingStatusFilter({
    super.key,
    required this.selectedFilter,
    required this.operatingCount,
    required this.closedCount,
    required this.permanentlyClosedCount,
    required this.onSelected,
  });

  final FacilityOperatingFilter selectedFilter;
  final int operatingCount;
  final int closedCount;
  final int permanentlyClosedCount;
  final ValueChanged<FacilityOperatingFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_outlined, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Text('営業状態で絞り込み', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _OperatingFilterChip(
                  label: 'すべて',
                  icon: Icons.grid_view_outlined,
                  count: operatingCount + closedCount + permanentlyClosedCount,
                  filter: FacilityOperatingFilter.all,
                  selected: selectedFilter == FacilityOperatingFilter.all,
                  onSelected: onSelected,
                ),
                const SizedBox(width: AppSpacing.sm),
                _OperatingFilterChip(
                  label: '営業中',
                  icon: Icons.check_circle_outline,
                  count: operatingCount,
                  filter: FacilityOperatingFilter.operatingOnly,
                  selected:
                      selectedFilter == FacilityOperatingFilter.operatingOnly,
                  onSelected: onSelected,
                ),
                const SizedBox(width: AppSpacing.sm),
                _OperatingFilterChip(
                  label: '休止中',
                  icon: Icons.pause_circle_outline,
                  count: closedCount,
                  filter: FacilityOperatingFilter.closedOnly,
                  selected:
                      selectedFilter == FacilityOperatingFilter.closedOnly,
                  onSelected: onSelected,
                ),
                const SizedBox(width: AppSpacing.sm),
                _OperatingFilterChip(
                  label: '運営終了',
                  icon: Icons.block_outlined,
                  count: permanentlyClosedCount,
                  filter: FacilityOperatingFilter.permanentlyClosedOnly,
                  selected:
                      selectedFilter ==
                      FacilityOperatingFilter.permanentlyClosedOnly,
                  onSelected: onSelected,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OperatingFilterChip extends StatelessWidget {
  const _OperatingFilterChip({
    required this.label,
    required this.icon,
    required this.count,
    required this.filter,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final int count;
  final FacilityOperatingFilter filter;
  final bool selected;
  final ValueChanged<FacilityOperatingFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final style = _visualStyle(filter, Theme.of(context).colorScheme);

    return FilterChip(
      selected: selected,
      showCheckmark: selected,
      avatar: selected
          ? null
          : Icon(icon, size: 17, color: style.foregroundColor),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, maxLines: 1, softWrap: false),
          const SizedBox(width: 6),
          Container(
            constraints: const BoxConstraints(minWidth: 22, minHeight: 20),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? style.selectedCountBackgroundColor
                  : style.countBackgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected
                    ? style.selectedCountForegroundColor
                    : style.foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      selectedColor: style.selectedBackgroundColor,
      checkmarkColor: style.selectedForegroundColor,
      backgroundColor: style.backgroundColor,
      labelStyle: TextStyle(
        color: selected ? style.selectedForegroundColor : style.foregroundColor,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      ),
      side: BorderSide(
        color: selected ? style.selectedBorderColor : style.borderColor,
        width: selected ? 1.5 : 1,
      ),
      onSelected: (_) {
        onSelected(filter);
      },
    );
  }

  _OperatingFilterVisualStyle _visualStyle(
    FacilityOperatingFilter filter,
    ColorScheme colorScheme,
  ) {
    return switch (filter) {
      FacilityOperatingFilter.all => _OperatingFilterVisualStyle(
        foregroundColor: colorScheme.onSurfaceVariant,
        backgroundColor: colorScheme.surface,
        borderColor: colorScheme.outlineVariant,
        selectedForegroundColor: colorScheme.onPrimaryContainer,
        selectedBackgroundColor: colorScheme.primaryContainer,
        selectedBorderColor: colorScheme.primary,
        countBackgroundColor: colorScheme.surfaceContainerHigh,
        selectedCountBackgroundColor: colorScheme.primary,
        selectedCountForegroundColor: colorScheme.onPrimary,
      ),
      FacilityOperatingFilter.operatingOnly =>
        const _OperatingFilterVisualStyle(
          foregroundColor: Color(0xFF287A4B),
          backgroundColor: Color(0xFFE8F5ED),
          borderColor: Color(0xFFA5D6B8),
          selectedForegroundColor: Colors.white,
          selectedBackgroundColor: Color(0xFF287A4B),
          selectedBorderColor: Color(0xFF1D6039),
          countBackgroundColor: Color(0xFFD3EBDD),
          selectedCountBackgroundColor: Colors.white,
          selectedCountForegroundColor: Color(0xFF287A4B),
        ),
      FacilityOperatingFilter.closedOnly => const _OperatingFilterVisualStyle(
        foregroundColor: Color(0xFF9A5B00),
        backgroundColor: Color(0xFFFFF3E0),
        borderColor: Color(0xFFFFB74D),
        selectedForegroundColor: Colors.white,
        selectedBackgroundColor: Color(0xFFB56600),
        selectedBorderColor: Color(0xFF8D4F00),
        countBackgroundColor: Color(0xFFFFE2B8),
        selectedCountBackgroundColor: Colors.white,
        selectedCountForegroundColor: Color(0xFF9A5B00),
      ),
      FacilityOperatingFilter.permanentlyClosedOnly =>
        const _OperatingFilterVisualStyle(
          foregroundColor: Color(0xFF505050),
          backgroundColor: Color(0xFFF0F0F0),
          borderColor: Color(0xFFBDBDBD),
          selectedForegroundColor: Colors.white,
          selectedBackgroundColor: Color(0xFF505050),
          selectedBorderColor: Color(0xFF333333),
          countBackgroundColor: Color(0xFFDDDDDD),
          selectedCountBackgroundColor: Colors.white,
          selectedCountForegroundColor: Color(0xFF505050),
        ),
    };
  }
}

class _OperatingFilterVisualStyle {
  const _OperatingFilterVisualStyle({
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.selectedForegroundColor,
    required this.selectedBackgroundColor,
    required this.selectedBorderColor,
    required this.countBackgroundColor,
    required this.selectedCountBackgroundColor,
    required this.selectedCountForegroundColor,
  });

  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color selectedForegroundColor;
  final Color selectedBackgroundColor;
  final Color selectedBorderColor;
  final Color countBackgroundColor;
  final Color selectedCountBackgroundColor;
  final Color selectedCountForegroundColor;
}
