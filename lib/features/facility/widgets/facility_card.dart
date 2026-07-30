import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/facility.dart';
import '../../../domain/enums/facility_operating_status.dart';
import 'facility_visual_style.dart';

class FacilityCard extends StatefulWidget {
  const FacilityCard({
    super.key,
    required this.facility,
    required this.isSelected,
    required this.onAdd,
    required this.onRemove,
  });

  final Facility facility;
  final bool isSelected;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  State<FacilityCard> createState() {
    return _FacilityCardState();
  }
}

class _FacilityCardState extends State<FacilityCard> {
  bool _isExpanded = false;

  Facility get facility {
    return widget.facility;
  }

  bool get _canAddToPlan {
    return facility.isOpen;
  }

  bool get _hasOperatingStatusDetails {
    return facility.operatingStatus != FacilityOperatingStatus.operating ||
        facility.closureStartDate != null ||
        facility.closureEndDate != null ||
        (facility.operatingStatusNote?.trim().isNotEmpty ?? false) ||
        facility.operatingStatusCheckedAt != null;
  }

  bool get _requiresPrioritySeating {
    return facility.supportsPrioritySeating ||
        facility.requiresReservation ||
        facility.reservationRequired;
  }

  bool get _hasExpandableDetails {
    return (facility.description?.trim().isNotEmpty ?? false) ||
        facility.primaryProductLabel != null ||
        (facility.menuNote?.trim().isNotEmpty ?? false) ||
        facility.isShowRestaurant ||
        _hasOperatingStatusDetails ||
        facility.hasMenuUrl ||
        facility.hasOfficialUrl;
  }

  @override
  Widget build(BuildContext context) {
    final areaStyle = FacilityVisualStyle.areaStyle(facility.areaId);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;

        return Opacity(
          opacity: _canAddToPlan ? 1 : 0.76,
          child: Stack(
            children: [
              AppCard(
                child: Padding(
                  padding: EdgeInsets.only(left: compact ? 2 : 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FacilityTitleRow(
                        facility: facility,
                        canAddToPlan: _canAddToPlan,
                        isSelected: widget.isSelected,
                        compact: compact,
                        onAdd: widget.onAdd,
                        onRemove: widget.onRemove,
                      ),
                      SizedBox(height: compact ? 7 : AppSpacing.sm),
                      _FacilityBadgeList(
                        facility: facility,
                        compact: compact,
                        requiresPrioritySeating: _requiresPrioritySeating,
                      ),
                      if (_hasExpandableDetails) ...[
                        SizedBox(height: compact ? 1 : AppSpacing.xs),
                        _DetailsToggle(
                          isExpanded: _isExpanded,
                          compact: compact,
                          onPressed: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                        ),
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 180),
                          sizeCurve: Curves.easeInOut,
                          crossFadeState: _isExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          firstChild: const SizedBox(width: double.infinity),
                          secondChild: _FacilityDetails(
                            facility: facility,
                            compact: compact,
                            showOperatingStatus: _hasOperatingStatusDetails,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 10,
                bottom: 10,
                child: Container(
                  width: compact ? 3 : 4,
                  decoration: BoxDecoration(
                    color: areaStyle.borderColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FacilityTitleRow extends StatelessWidget {
  const _FacilityTitleRow({
    required this.facility,
    required this.canAddToPlan,
    required this.isSelected,
    required this.compact,
    required this.onAdd,
    required this.onRemove,
  });

  final Facility facility;
  final bool canAddToPlan;
  final bool isSelected;
  final bool compact;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            facility.name,
            maxLines: compact ? 2 : 2,
            overflow: TextOverflow.ellipsis,
            style: compact
                ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.22,
                  )
                : Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
          ),
        ),
        SizedBox(width: compact ? 6 : 10),
        _CompactFacilityAction(
          facility: facility,
          canAddToPlan: canAddToPlan,
          isSelected: isSelected,
          compact: compact,
          onAdd: onAdd,
          onRemove: onRemove,
        ),
      ],
    );
  }
}

class _CompactFacilityAction extends StatelessWidget {
  const _CompactFacilityAction({
    required this.facility,
    required this.canAddToPlan,
    required this.isSelected,
    required this.compact,
    required this.onAdd,
    required this.onRemove,
  });

  final Facility facility;
  final bool canAddToPlan;
  final bool isSelected;
  final bool compact;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!canAddToPlan) {
      final message =
          facility.operatingStatus == FacilityOperatingStatus.permanentlyClosed
          ? '運営終了のため追加できません'
          : '現在はプランに追加できません';

      if (compact) {
        return Tooltip(
          message: message,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.block_outlined,
              size: 19,
              color: colorScheme.onErrorContainer,
            ),
          ),
        );
      }

      return Tooltip(
        message: message,
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.block_outlined,
                size: 16,
                color: colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 4),
              Text(
                '追加不可',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (compact) {
      if (isSelected) {
        return Tooltip(
          message: 'プランから削除',
          child: Material(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onRemove,
              child: SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  Icons.check,
                  size: 20,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        );
      }

      return Tooltip(
        message: 'プランに追加',
        child: Material(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onAdd,
            child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(Icons.add, size: 21, color: colorScheme.onPrimary),
            ),
          ),
        ),
      );
    }

    if (isSelected) {
      return OutlinedButton.icon(
        onPressed: onRemove,
        icon: const Icon(Icons.check, size: 17),
        label: const Text('追加済み'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    return FilledButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.add, size: 17),
      label: const Text('追加'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 11),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _FacilityBadgeList extends StatelessWidget {
  const _FacilityBadgeList({
    required this.facility,
    required this.compact,
    required this.requiresPrioritySeating,
  });

  final Facility facility;
  final bool compact;
  final bool requiresPrioritySeating;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: compact ? 4 : 6,
      runSpacing: compact ? 4 : 6,
      children: [
        _CategoryBadge(facility: facility, compact: compact),
        _AreaBadge(areaId: facility.areaId, compact: compact),
        _CompactBadge(
          icon: Icons.schedule_outlined,
          label: '約${facility.durationMinutes}分',
          compact: compact,
          foregroundColor: const Color(0xFF514F66),
          backgroundColor: const Color(0xFFF7F5FC),
          borderColor: const Color(0xFFD5D0E0),
        ),
        if (facility.operatingStatus != FacilityOperatingStatus.operating ||
            !facility.isOpen)
          _OperatingStatusBadge(facility: facility, compact: compact),
        if (facility.supportsDpa)
          _CompactBadge(
            icon: Icons.bolt,
            label: 'DPA',
            compact: compact,
            foregroundColor: const Color(0xFF0277BD),
            backgroundColor: const Color(0xFFE3F2FD),
            borderColor: const Color(0xFF90CAF9),
          ),
        if (facility.supportsPriorityPass)
          _CompactBadge(
            icon: Icons.confirmation_number_outlined,
            label: compact ? 'PP' : 'プライオリティパス',
            compact: compact,
            foregroundColor: const Color(0xFF6750A4),
            backgroundColor: const Color(0xFFEDE7F6),
            borderColor: const Color(0xFFB39DDB),
          ),
        if (facility.supportsSingleRider)
          _CompactBadge(
            icon: Icons.person_outline,
            label: compact ? 'シングル' : 'シングルライダー',
            compact: compact,
            foregroundColor: const Color(0xFF2E7D32),
            backgroundColor: const Color(0xFFE8F5E9),
            borderColor: const Color(0xFFA5D6A7),
          ),
        if (facility.requiresEntryRequest)
          _CompactBadge(
            icon: Icons.how_to_reg_outlined,
            label: compact ? 'エントリー' : 'エントリー受付',
            compact: compact,
            foregroundColor: const Color(0xFFEF6C00),
            backgroundColor: const Color(0xFFFFF3E0),
            borderColor: const Color(0xFFFFB74D),
          ),
        if (facility.supportsStandbyPass)
          _CompactBadge(
            icon: Icons.airplane_ticket_outlined,
            label: compact ? 'SP' : 'スタンバイパス',
            compact: compact,
            foregroundColor: const Color(0xFF8A6D00),
            backgroundColor: const Color(0xFFFFF8E1),
            borderColor: const Color(0xFFFFD54F),
          ),
        if (facility.supportsMobileOrder)
          _CompactBadge(
            icon: Icons.phone_iphone_outlined,
            label: compact ? 'MO' : 'モバイルオーダー',
            compact: compact,
            foregroundColor: const Color(0xFF00796B),
            backgroundColor: const Color(0xFFE0F2F1),
            borderColor: const Color(0xFF80CBC4),
          ),
        if (requiresPrioritySeating)
          _CompactBadge(
            icon: Icons.event_available_outlined,
            label: compact ? 'PS' : 'プライオリティ・シーティング',
            compact: compact,
            foregroundColor: const Color(0xFFC62828),
            backgroundColor: const Color(0xFFFFEBEE),
            borderColor: const Color(0xFFEF9A9A),
          ),
      ],
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.facility, required this.compact});

  final Facility facility;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = FacilityVisualStyle.categoryStyle(facility);

    return Container(
      constraints: BoxConstraints(minHeight: compact ? 26 : 30),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(compact ? 7 : 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            style.icon,
            size: compact ? 13 : 15,
            color: style.foregroundColor,
          ),
          SizedBox(width: compact ? 4 : 5),
          Text(
            style.label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: style.foregroundColor,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaBadge extends StatelessWidget {
  const _AreaBadge({required this.areaId, required this.compact});

  final String areaId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = FacilityVisualStyle.areaStyle(areaId);

    return Container(
      constraints: BoxConstraints(minHeight: compact ? 26 : 30),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(compact ? 7 : 8),
        border: Border.all(color: style.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            style.icon,
            size: compact ? 13 : 15,
            color: style.foregroundColor,
          ),
          SizedBox(width: compact ? 4 : 5),
          Text(
            style.label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: style.foregroundColor,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactBadge extends StatelessWidget {
  const _CompactBadge({
    required this.icon,
    required this.label,
    required this.compact,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final String label;
  final bool compact;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 26 : 30),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(compact ? 7 : 8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 15, color: foregroundColor),
          SizedBox(width: compact ? 4 : 5),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _OperatingStatusBadge extends StatelessWidget {
  const _OperatingStatusBadge({required this.facility, required this.compact});

  final Facility facility;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = _style;

    return _CompactBadge(
      icon: style.icon,
      label: facility.operatingStatusDisplayLabel,
      compact: compact,
      foregroundColor: style.foregroundColor,
      backgroundColor: style.backgroundColor,
      borderColor: style.borderColor,
    );
  }

  _OperatingBadgeStyle get _style {
    return switch (facility.operatingStatus) {
      FacilityOperatingStatus.operating => const _OperatingBadgeStyle(
        icon: Icons.warning_amber_outlined,
        foregroundColor: Color(0xFFC62828),
        backgroundColor: Color(0xFFFFEBEE),
        borderColor: Color(0xFFEF9A9A),
      ),
      FacilityOperatingStatus.scheduledClosure => const _OperatingBadgeStyle(
        icon: Icons.event_busy_outlined,
        foregroundColor: Color(0xFF8A6D00),
        backgroundColor: Color(0xFFFFF8E1),
        borderColor: Color(0xFFFFD54F),
      ),
      FacilityOperatingStatus.temporarilyClosed => const _OperatingBadgeStyle(
        icon: Icons.pause_circle_outline,
        foregroundColor: Color(0xFFEF6C00),
        backgroundColor: Color(0xFFFFF3E0),
        borderColor: Color(0xFFFFB74D),
      ),
      FacilityOperatingStatus.seasonalClosed => const _OperatingBadgeStyle(
        icon: Icons.ac_unit_outlined,
        foregroundColor: Color(0xFF1565C0),
        backgroundColor: Color(0xFFE3F2FD),
        borderColor: Color(0xFF90CAF9),
      ),
      FacilityOperatingStatus.longTermClosed => const _OperatingBadgeStyle(
        icon: Icons.warning_amber_outlined,
        foregroundColor: Color(0xFFC62828),
        backgroundColor: Color(0xFFFFEBEE),
        borderColor: Color(0xFFEF9A9A),
      ),
      FacilityOperatingStatus.permanentlyClosed => const _OperatingBadgeStyle(
        icon: Icons.block_outlined,
        foregroundColor: Color(0xFF424242),
        backgroundColor: Color(0xFFEEEEEE),
        borderColor: Color(0xFFBDBDBD),
      ),
    };
  }
}

class _OperatingBadgeStyle {
  const _OperatingBadgeStyle({
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
}

class _DetailsToggle extends StatelessWidget {
  const _DetailsToggle({
    required this.isExpanded,
    required this.compact,
    required this.onPressed,
  });

  final bool isExpanded;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: AnimatedRotation(
          turns: isExpanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 180),
          child: Icon(Icons.keyboard_arrow_down, size: compact ? 17 : 19),
        ),
        label: Text(isExpanded ? '詳細を閉じる' : '詳細を見る'),
        style: TextButton.styleFrom(
          minimumSize: Size(0, compact ? 28 : 32),
          padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: compact ? Theme.of(context).textTheme.bodySmall : null,
        ),
      ),
    );
  }
}

class _FacilityDetails extends StatelessWidget {
  const _FacilityDetails({
    required this.facility,
    required this.compact,
    required this.showOperatingStatus,
  });

  final Facility facility;
  final bool compact;
  final bool showOperatingStatus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(top: compact ? 2 : AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showOperatingStatus)
            _OperatingStatusDetails(facility: facility, compact: compact),
          if (facility.isShowRestaurant &&
              facility.showName != null &&
              facility.showName!.trim().isNotEmpty) ...[
            SizedBox(height: compact ? 6 : AppSpacing.sm),
            _DetailRow(
              icon: Icons.theater_comedy_outlined,
              label: facility.showName!,
              emphasized: true,
            ),
          ],
          if (facility.primaryProductLabel != null) ...[
            SizedBox(height: compact ? 6 : AppSpacing.sm),
            _DetailRow(
              icon: facility.isPopcornWagon
                  ? Icons.local_movies_outlined
                  : Icons.restaurant_menu_outlined,
              label: facility.isPopcornWagon
                  ? facility.primaryProductLabel!
                  : '代表：${facility.primaryProductLabel!}',
              emphasized: true,
            ),
          ],
          if (facility.menuNote != null &&
              facility.menuNote!.trim().isNotEmpty) ...[
            SizedBox(height: compact ? 3 : AppSpacing.xs),
            Text(
              facility.menuNote!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          if (facility.description != null &&
              facility.description!.trim().isNotEmpty) ...[
            SizedBox(height: compact ? 6 : AppSpacing.sm),
            Text(
              facility.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
          if (facility.hasMenuUrl || facility.hasOfficialUrl) ...[
            SizedBox(height: compact ? 6 : AppSpacing.sm),
            _FacilityLinks(facility: facility, compact: compact),
          ],
        ],
      ),
    );
  }
}

class _OperatingStatusDetails extends StatelessWidget {
  const _OperatingStatusDetails({
    required this.facility,
    required this.compact,
  });

  final Facility facility;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final period = facility.closurePeriodLabel;
    final note = facility.operatingStatusNote?.trim();
    final checkedAt = facility.operatingStatusCheckedAt;

    final rows = <Widget>[];

    if (period != null) {
      rows.add(
        _DetailRow(icon: Icons.date_range_outlined, label: '休止期間：$period'),
      );
    }

    if (note != null && note.isNotEmpty) {
      rows.add(_DetailRow(icon: Icons.info_outline, label: note));
    }

    if (checkedAt != null) {
      rows.add(
        _DetailRow(
          icon: Icons.verified_outlined,
          label: '公式情報確認：${_formatDate(checkedAt)}',
        ),
      );
    }

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 7 : 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const SizedBox(height: 5),
            rows[index],
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    return '${value.year}年${value.month}月${value.day}日';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _FacilityLinks extends StatelessWidget {
  const _FacilityLinks({required this.facility, required this.compact});

  final Facility facility;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (facility.hasMenuUrl)
          OutlinedButton.icon(
            onPressed: () {
              _openUrl(context, facility.menuUrl!);
            },
            icon: const Icon(Icons.restaurant_menu_outlined, size: 17),
            label: const Text('メニュー'),
            style: OutlinedButton.styleFrom(
              minimumSize: Size(0, compact ? 32 : 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        if (facility.hasOfficialUrl)
          TextButton.icon(
            onPressed: () {
              _openUrl(context, facility.officialUrl!);
            },
            icon: const Icon(Icons.open_in_new, size: 17),
            label: const Text('公式'),
            style: TextButton.styleFrom(
              minimumSize: Size(0, compact ? 32 : 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }

  Future<void> _openUrl(BuildContext context, String source) async {
    final uri = Uri.tryParse(source);

    if (uri == null) {
      _showUrlError(context);

      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      _showUrlError(context);
    }
  }

  void _showUrlError(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('ページを開けませんでした。')));
  }
}
