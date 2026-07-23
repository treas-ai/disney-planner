import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

class FacilityAreaFilter extends StatefulWidget {
  const FacilityAreaFilter({
    super.key,
    required this.areaIds,
    required this.selectedAreaId,
    required this.areaLabelBuilder,
    required this.onSelected,
  });

  final List<String> areaIds;
  final String? selectedAreaId;
  final String Function(String areaId) areaLabelBuilder;
  final ValueChanged<String?> onSelected;

  @override
  State<FacilityAreaFilter> createState() {
    return _FacilityAreaFilterState();
  }
}

class _FacilityAreaFilterState extends State<FacilityAreaFilter> {
  static const double _scrollAmount = 280;

  final ScrollController _scrollController = ScrollController();

  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_updateScrollButtonState);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollButtonState();
    });
  }

  @override
  void didUpdateWidget(covariant FacilityAreaFilter oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.areaIds != widget.areaIds) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateScrollButtonState();
      });
    }

    if (oldWidget.selectedAreaId != widget.selectedAreaId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollSelectedAreaIntoView();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollButtonState);

    _scrollController.dispose();

    super.dispose();
  }

  void _updateScrollButtonState() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;

    final canScrollLeft = position.pixels > position.minScrollExtent + 1;

    final canScrollRight = position.pixels < position.maxScrollExtent - 1;

    if (_canScrollLeft == canScrollLeft && _canScrollRight == canScrollRight) {
      return;
    }

    setState(() {
      _canScrollLeft = canScrollLeft;
      _canScrollRight = canScrollRight;
    });
  }

  Future<void> _scrollLeft() async {
    if (!_scrollController.hasClients || !_canScrollLeft) {
      return;
    }

    final position = _scrollController.position;

    final target = (position.pixels - _scrollAmount).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    await _scrollController.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _scrollRight() async {
    if (!_scrollController.hasClients || !_canScrollRight) {
      return;
    }

    final position = _scrollController.position;

    final target = (position.pixels + _scrollAmount).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    await _scrollController.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _scrollSelectedAreaIntoView() async {
    if (!_scrollController.hasClients) {
      return;
    }

    final selectedAreaId = widget.selectedAreaId;

    if (selectedAreaId == null) {
      return;
    }

    final selectedIndex = widget.areaIds.indexOf(selectedAreaId);

    if (selectedIndex < 0) {
      return;
    }

    final position = _scrollController.position;

    const estimatedChipWidth = 190.0;

    final estimatedTarget = selectedIndex * estimatedChipWidth;

    final target = estimatedTarget.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    await _scrollController.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _selectArea(String areaId) {
    if (widget.selectedAreaId == areaId) {
      widget.onSelected(null);
      return;
    }

    widget.onSelected(areaId);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.areaIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Text('エリアで絞り込み', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 48,
            child: Row(
              children: [
                _AreaFilterChip(
                  label: 'すべてのエリア',
                  selected: widget.selectedAreaId == null,
                  icon: Icons.public_outlined,
                  onSelected: () {
                    widget.onSelected(null);
                  },
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 1,
                  height: 32,
                  color: colorScheme.outlineVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                _ScrollArrowButton(
                  tooltip: '前のエリアを表示',
                  icon: Icons.chevron_left,
                  enabled: _canScrollLeft,
                  onPressed: _scrollLeft,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: ClipRect(
                    child: ListView.separated(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      itemCount: widget.areaIds.length,
                      separatorBuilder: (context, index) {
                        return const SizedBox(width: AppSpacing.sm);
                      },
                      itemBuilder: (context, index) {
                        final areaId = widget.areaIds[index];

                        return _AreaFilterChip(
                          label: widget.areaLabelBuilder(areaId),
                          selected: widget.selectedAreaId == areaId,
                          icon: _iconForArea(areaId),
                          onSelected: () {
                            _selectArea(areaId);
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                _ScrollArrowButton(
                  tooltip: '次のエリアを表示',
                  icon: Icons.chevron_right,
                  enabled: _canScrollRight,
                  onPressed: _scrollRight,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForArea(String areaId) {
    return switch (areaId) {
      'tdl_world_bazaar' => Icons.storefront_outlined,
      'tdl_adventureland' => Icons.forest_outlined,
      'tdl_westernland' => Icons.landscape_outlined,
      'tdl_critter_country' => Icons.pets_outlined,
      'tdl_fantasyland' => Icons.castle_outlined,
      'tdl_new_fantasyland' => Icons.auto_awesome_outlined,
      'tdl_toontown' => Icons.house_outlined,
      'tdl_tomorrowland' => Icons.rocket_launch_outlined,
      'tds_mediterranean_harbor' => Icons.sailing_outlined,
      'tds_american_waterfront' => Icons.directions_boat_outlined,
      'tds_port_discovery' => Icons.explore_outlined,
      'tds_lost_river_delta' => Icons.temple_buddhist_outlined,
      'tds_arabian_coast' => Icons.nightlight_outlined,
      'tds_mermaid_lagoon' => Icons.water_outlined,
      'tds_mysterious_island' => Icons.terrain_outlined,
      'tds_fantasy_springs' => Icons.auto_awesome_outlined,
      _ => Icons.place_outlined,
    };
  }
}

class _ScrollArrowButton extends StatelessWidget {
  const _ScrollArrowButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled
            ? colorScheme.surfaceContainerHigh
            : colorScheme.surfaceContainerLow,
        shape: CircleBorder(
          side: BorderSide(
            color: enabled
                ? colorScheme.outlineVariant
                : colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              icon,
              size: 24,
              color: enabled
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}

class _AreaFilterChip extends StatelessWidget {
  const _AreaFilterChip({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      selected: selected,
      showCheckmark: selected,
      avatar: selected ? null : Icon(icon, size: 18),
      label: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
      ),
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
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected ? colorScheme.primary : colorScheme.outlineVariant,
      ),
      onSelected: (_) {
        onSelected();
      },
    );
  }
}
