import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/facility.dart';
import '../../../domain/enums/facility_category.dart';
import 'facility_visual_style.dart';
import '../facility_controller.dart';
import '../facility_operating_filter.dart';

class UnifiedFacilityFilterPanel extends StatefulWidget {
  const UnifiedFacilityFilterPanel({
    super.key,
    required this.controller,
    required this.onClearFilters,
  });

  final FacilityController controller;
  final VoidCallback onClearFilters;

  @override
  State<UnifiedFacilityFilterPanel> createState() {
    return _UnifiedFacilityFilterPanelState();
  }
}

class _UnifiedFacilityFilterPanelState
    extends State<UnifiedFacilityFilterPanel> {
  bool _isExpanded = true;

  FacilityController get controller {
    return widget.controller;
  }

  @override
  Widget build(BuildContext context) {
    final parkFacilities = controller.parkFacilities;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.tune_outlined, size: 21),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '絞り込み・並び替え',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (!_isExpanded) ...[
                          const SizedBox(height: 2),
                          Text(
                            _collapsedSummary(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeInOut,
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),
                _FilterGroup(
                  title: 'カテゴリで絞り込み',
                  icon: Icons.category_outlined,
                  child: _CompactHorizontalFilterList(
                    key: const ValueKey('category_filter'),
                    items: _categoryItems(parkFacilities),
                    selectedId: controller.selectedCategory?.name ?? 'all',
                    onSelected: (id) {
                      if (id == 'all') {
                        controller.selectCategory(null);
                        return;
                      }

                      final category = FacilityCategory.values.firstWhere(
                        (value) => value.name == id,
                      );

                      controller.selectCategory(category);
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _FilterGroup(
                  title: 'エリアで絞り込み',
                  icon: Icons.location_on_outlined,
                  child: _CompactHorizontalFilterList(
                    key: const ValueKey('area_filter'),
                    items: _areaItems(controller, parkFacilities),
                    selectedId: controller.selectedAreaId ?? 'all',
                    onSelected: (id) {
                      controller.selectArea(id == 'all' ? null : id);
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _FilterGroup(
                  title: '営業状態で絞り込み',
                  icon: Icons.schedule_outlined,
                  child: _CompactHorizontalFilterList(
                    key: const ValueKey('operating_filter'),
                    items: [
                      _FilterItem.all(
                        count: parkFacilities.length,
                        label: 'すべて',
                        icon: Icons.done_all_outlined,
                      ),
                      _FilterItem.operating(
                        count: controller.operatingFacilityCount,
                      ),
                      _FilterItem.closed(count: controller.closedFacilityCount),
                      _FilterItem.permanentlyClosed(
                        count: controller.permanentlyClosedFacilityCount,
                      ),
                    ],
                    selectedId: controller.selectedOperatingFilter.name,
                    onSelected: (id) {
                      final filter = FacilityOperatingFilter.values.firstWhere(
                        (value) => value.name == id,
                      );

                      controller.selectOperatingFilter(filter);
                    },
                  ),
                ),
                if (controller.hasActiveFilters) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: widget.onClearFilters,
                      icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
                      label: const Text('検索条件をすべて解除'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _collapsedSummary() {
    final category = controller.selectedCategory;
    final areaId = controller.selectedAreaId;

    return [
      category == null ? 'カテゴリ：すべて' : 'カテゴリ：${_categoryDisplayLabel(category)}',
      areaId == null ? 'エリア：すべて' : 'エリア：${controller.areaLabel(areaId)}',
      '営業状態：${_operatingFilterLabel(controller.selectedOperatingFilter)}',
    ].join('・');
  }

  String _categoryDisplayLabel(FacilityCategory category) {
    return FacilityVisualStyle.categoryStyleForCategory(category).label;
  }

  String _operatingFilterLabel(FacilityOperatingFilter filter) {
    return switch (filter) {
      FacilityOperatingFilter.all => 'すべて',
      FacilityOperatingFilter.operatingOnly => '営業中',
      FacilityOperatingFilter.closedOnly => '休止中',
      FacilityOperatingFilter.permanentlyClosedOnly => '終了',
    };
  }

  List<_FilterItem> _categoryItems(List<Facility> facilities) {
    final counts = <FacilityCategory, int>{};

    for (final facility in facilities) {
      final normalizedCategory = facility.category == FacilityCategory.parade
          ? FacilityCategory.show
          : facility.category;

      counts.update(
        normalizedCategory,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    return [
      _FilterItem.all(
        count: facilities.length,
        label: 'すべて',
        icon: Icons.done_all_outlined,
      ),
      for (final category in FacilityCategory.values)
        if (category != FacilityCategory.parade)
          _FilterItem.category(
            category: category,
            count: counts[category] ?? 0,
          ),
    ];
  }

  List<_FilterItem> _areaItems(
    FacilityController controller,
    List<Facility> facilities,
  ) {
    final counts = <String, int>{};

    for (final facility in facilities) {
      counts.update(facility.areaId, (value) => value + 1, ifAbsent: () => 1);
    }

    return [
      _FilterItem.all(
        count: facilities.length,
        label: 'すべてのエリア',
        icon: Icons.public_outlined,
      ),
      for (final areaId in controller.availableAreaIds)
        _FilterItem.area(
          areaId: areaId,
          fallbackLabel: controller.areaLabel(areaId),
          count: counts[areaId] ?? 0,
        ),
    ];
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _CompactHorizontalFilterList extends StatefulWidget {
  const _CompactHorizontalFilterList({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  final List<_FilterItem> items;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  State<_CompactHorizontalFilterList> createState() {
    return _CompactHorizontalFilterListState();
  }
}

class _CompactHorizontalFilterListState
    extends State<_CompactHorizontalFilterList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _CompactHorizontalFilterList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedId != widget.selectedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollSelectedIntoView();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollSelectedIntoView() async {
    if (!_scrollController.hasClients) {
      return;
    }

    final selectedIndex = widget.items.indexWhere(
      (item) => item.id == widget.selectedId,
    );

    if (selectedIndex < 0) {
      return;
    }

    const estimatedItemWidth = 118.0;
    final position = _scrollController.position;

    final target = (selectedIndex * estimatedItemWidth).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    await _scrollController.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        interactive: true,
        thickness: 4,
        radius: const Radius.circular(8),
        notificationPredicate: (notification) {
          return notification.depth == 0;
        },
        child: ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(left: 1, right: 1, bottom: 8),
          itemCount: widget.items.length,
          separatorBuilder: (context, index) {
            return const SizedBox(width: 6);
          },
          itemBuilder: (context, index) {
            final item = widget.items[index];

            return _CompactFilterChip(
              item: item,
              selected: item.id == widget.selectedId,
              onPressed: () {
                widget.onSelected(item.id);
              },
            );
          },
        ),
      ),
    );
  }
}

class _CompactFilterChip extends StatelessWidget {
  const _CompactFilterChip({
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  final _FilterItem item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final visual = item.visual(context);
    final backgroundColor = selected
        ? visual.selectedBackgroundColor
        : visual.backgroundColor;
    final foregroundColor = visual.foregroundColor;
    final borderColor = selected
        ? visual.selectedBorderColor
        : visual.borderColor;

    return Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor, width: selected ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check : item.icon,
                size: 15,
                color: foregroundColor,
              ),
              const SizedBox(width: 5),
              Text(
                item.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foregroundColor,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 22, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? visual.selectedCountBackgroundColor
                      : visual.countBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item.count}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected
                        ? visual.selectedCountForegroundColor
                        : visual.countForegroundColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterItem {
  const _FilterItem._({
    required this.id,
    required this.label,
    required this.count,
    required this.icon,
    required this.kind,
    this.category,
    this.areaId,
  });

  factory _FilterItem.all({
    required int count,
    required String label,
    required IconData icon,
  }) {
    return _FilterItem._(
      id: 'all',
      label: label,
      count: count,
      icon: icon,
      kind: _FilterItemKind.all,
    );
  }

  factory _FilterItem.category({
    required FacilityCategory category,
    required int count,
  }) {
    final style = FacilityVisualStyle.categoryStyleForCategory(category);

    return _FilterItem._(
      id: category.name,
      label: style.label,
      count: count,
      icon: style.icon,
      kind: _FilterItemKind.category,
      category: category,
    );
  }

  factory _FilterItem.area({
    required String areaId,
    required String fallbackLabel,
    required int count,
  }) {
    final style = FacilityVisualStyle.areaStyle(areaId);

    return _FilterItem._(
      id: areaId,
      label: style.label == areaId ? fallbackLabel : style.label,
      count: count,
      icon: style.icon,
      kind: _FilterItemKind.area,
      areaId: areaId,
    );
  }

  factory _FilterItem.operating({required int count}) {
    return _FilterItem._(
      id: FacilityOperatingFilter.operatingOnly.name,
      label: '営業中',
      count: count,
      icon: Icons.check_circle_outline,
      kind: _FilterItemKind.operating,
    );
  }

  factory _FilterItem.closed({required int count}) {
    return _FilterItem._(
      id: FacilityOperatingFilter.closedOnly.name,
      label: '休止中',
      count: count,
      icon: Icons.pause_circle_outline,
      kind: _FilterItemKind.closed,
    );
  }

  factory _FilterItem.permanentlyClosed({required int count}) {
    return _FilterItem._(
      id: FacilityOperatingFilter.permanentlyClosedOnly.name,
      label: '終了',
      count: count,
      icon: Icons.block_outlined,
      kind: _FilterItemKind.permanentlyClosed,
    );
  }

  final String id;
  final String label;
  final int count;
  final IconData icon;
  final _FilterItemKind kind;
  final FacilityCategory? category;
  final String? areaId;

  _FilterChipVisual visual(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return switch (kind) {
      _FilterItemKind.all => _FilterChipVisual(
        foregroundColor: colorScheme.onPrimaryContainer,
        backgroundColor: colorScheme.primaryContainer,
        borderColor: colorScheme.primary.withValues(alpha: 0.55),
        countForegroundColor: colorScheme.onPrimary,
        countBackgroundColor: colorScheme.primary,
        selectedBackgroundColor: colorScheme.primaryContainer,
        selectedBorderColor: colorScheme.primary,
        selectedCountForegroundColor: colorScheme.onPrimary,
        selectedCountBackgroundColor: colorScheme.primary,
      ),
      _FilterItemKind.category => _categoryVisual(category!),
      _FilterItemKind.area => _areaVisual(areaId!),
      _FilterItemKind.operating => const _FilterChipVisual(
        foregroundColor: Color(0xFF2E7D32),
        backgroundColor: Color(0xFFE8F5E9),
        borderColor: Color(0xFFA5D6A7),
        countForegroundColor: Color(0xFF2E7D32),
        countBackgroundColor: Color(0xFFD7ECD9),
        selectedBackgroundColor: Color(0xFFD7ECD9),
        selectedBorderColor: Color(0xFF2E7D32),
        selectedCountForegroundColor: Colors.white,
        selectedCountBackgroundColor: Color(0xFF2E7D32),
      ),
      _FilterItemKind.closed => const _FilterChipVisual(
        foregroundColor: Color(0xFFEF6C00),
        backgroundColor: Color(0xFFFFF3E0),
        borderColor: Color(0xFFFFB74D),
        countForegroundColor: Color(0xFFEF6C00),
        countBackgroundColor: Color(0xFFFFE0B2),
        selectedBackgroundColor: Color(0xFFFFE0B2),
        selectedBorderColor: Color(0xFFEF6C00),
        selectedCountForegroundColor: Colors.white,
        selectedCountBackgroundColor: Color(0xFFEF6C00),
      ),
      _FilterItemKind.permanentlyClosed => const _FilterChipVisual(
        foregroundColor: Color(0xFFC62828),
        backgroundColor: Color(0xFFFFEBEE),
        borderColor: Color(0xFFEF9A9A),
        countForegroundColor: Color(0xFFC62828),
        countBackgroundColor: Color(0xFFFFCDD2),
        selectedBackgroundColor: Color(0xFFFFCDD2),
        selectedBorderColor: Color(0xFFC62828),
        selectedCountForegroundColor: Colors.white,
        selectedCountBackgroundColor: Color(0xFFC62828),
      ),
    };
  }

  _FilterChipVisual _categoryVisual(FacilityCategory category) {
    final style = FacilityVisualStyle.categoryStyleForCategory(category);

    return _FilterChipVisual(
      foregroundColor: style.backgroundColor,
      backgroundColor: style.backgroundColor.withValues(alpha: 0.10),
      borderColor: style.backgroundColor.withValues(alpha: 0.42),
      countForegroundColor: style.backgroundColor,
      countBackgroundColor: style.backgroundColor.withValues(alpha: 0.16),
      selectedBackgroundColor: style.backgroundColor.withValues(alpha: 0.18),
      selectedBorderColor: style.backgroundColor,
      selectedCountForegroundColor: style.foregroundColor,
      selectedCountBackgroundColor: style.backgroundColor,
    );
  }

  _FilterChipVisual _areaVisual(String areaId) {
    final style = FacilityVisualStyle.areaStyle(areaId);

    return _FilterChipVisual(
      foregroundColor: style.foregroundColor,
      backgroundColor: style.backgroundColor,
      borderColor: style.borderColor,
      countForegroundColor: style.foregroundColor,
      countBackgroundColor: Color.alphaBlend(
        style.borderColor.withValues(alpha: 0.18),
        style.backgroundColor,
      ),
      selectedBackgroundColor: Color.alphaBlend(
        style.borderColor.withValues(alpha: 0.22),
        style.backgroundColor,
      ),
      selectedBorderColor: style.foregroundColor,
      selectedCountForegroundColor: Colors.white,
      selectedCountBackgroundColor: style.foregroundColor,
    );
  }
}

enum _FilterItemKind {
  all,
  category,
  area,
  operating,
  closed,
  permanentlyClosed,
}

class _FilterChipVisual {
  const _FilterChipVisual({
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.countForegroundColor,
    required this.countBackgroundColor,
    required this.selectedBackgroundColor,
    required this.selectedBorderColor,
    required this.selectedCountForegroundColor,
    required this.selectedCountBackgroundColor,
  });

  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color countForegroundColor;
  final Color countBackgroundColor;
  final Color selectedBackgroundColor;
  final Color selectedBorderColor;
  final Color selectedCountForegroundColor;
  final Color selectedCountBackgroundColor;
}
