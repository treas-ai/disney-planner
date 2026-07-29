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
    return Opacity(
      opacity: _canAddToPlan ? 1 : 0.76,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FacilityTitleRow(
              facility: facility,
              canAddToPlan: _canAddToPlan,
              isSelected: widget.isSelected,
              onAdd: widget.onAdd,
              onRemove: widget.onRemove,
            ),
            const SizedBox(height: AppSpacing.sm),
            _FacilityBadgeList(
              facility: facility,
              requiresPrioritySeating: _requiresPrioritySeating,
            ),
            if (_hasExpandableDetails) ...[
              const SizedBox(height: AppSpacing.xs),
              _DetailsToggle(
                isExpanded: _isExpanded,
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
                  showOperatingStatus: _hasOperatingStatusDetails,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FacilityTitleRow extends StatelessWidget {
  const _FacilityTitleRow({
    required this.facility,
    required this.canAddToPlan,
    required this.isSelected,
    required this.onAdd,
    required this.onRemove,
  });

  final Facility facility;
  final bool canAddToPlan;
  final bool isSelected;
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _CompactFacilityAction(
          facility: facility,
          canAddToPlan: canAddToPlan,
          isSelected: isSelected,
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
    required this.onAdd,
    required this.onRemove,
  });

  final Facility facility;
  final bool canAddToPlan;
  final bool isSelected;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (!canAddToPlan) {
      return Tooltip(
        message:
            facility.operatingStatus ==
                FacilityOperatingStatus.permanentlyClosed
            ? '運営終了のため追加できません'
            : '現在はプランに追加できません',
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.block_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 4),
              Text(
                '追加不可',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
    required this.requiresPrioritySeating,
  });

  final Facility facility;
  final bool requiresPrioritySeating;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _CategoryBadge(facility: facility),
        _AreaBadge(areaId: facility.areaId),
        _CompactBadge(
          icon: Icons.schedule_outlined,
          label: '約${facility.durationMinutes}分',
          foregroundColor: const Color(0xFF514F66),
          backgroundColor: const Color(0xFFF7F5FC),
          borderColor: const Color(0xFFD5D0E0),
        ),
        if (facility.operatingStatus != FacilityOperatingStatus.operating ||
            !facility.isOpen)
          _OperatingStatusBadge(facility: facility),
        if (facility.supportsDpa)
          const _CompactBadge(
            icon: Icons.bolt,
            label: 'DPA',
            foregroundColor: Color(0xFF0277BD),
            backgroundColor: Color(0xFFE3F2FD),
            borderColor: Color(0xFF90CAF9),
          ),
        if (facility.supportsPriorityPass)
          const _CompactBadge(
            icon: Icons.confirmation_number_outlined,
            label: 'プライオリティパス',
            foregroundColor: Color(0xFF6750A4),
            backgroundColor: Color(0xFFEDE7F6),
            borderColor: Color(0xFFB39DDB),
          ),
        if (facility.supportsSingleRider)
          const _CompactBadge(
            icon: Icons.person_outline,
            label: 'シングルライダー',
            foregroundColor: Color(0xFF2E7D32),
            backgroundColor: Color(0xFFE8F5E9),
            borderColor: Color(0xFFA5D6A7),
          ),
        if (facility.requiresEntryRequest)
          const _CompactBadge(
            icon: Icons.how_to_reg_outlined,
            label: 'エントリー受付',
            foregroundColor: Color(0xFFEF6C00),
            backgroundColor: Color(0xFFFFF3E0),
            borderColor: Color(0xFFFFB74D),
          ),
        if (facility.supportsStandbyPass)
          const _CompactBadge(
            icon: Icons.airplane_ticket_outlined,
            label: 'スタンバイパス',
            foregroundColor: Color(0xFF8A6D00),
            backgroundColor: Color(0xFFFFF8E1),
            borderColor: Color(0xFFFFD54F),
          ),
        if (facility.supportsMobileOrder)
          const _CompactBadge(
            icon: Icons.phone_iphone_outlined,
            label: 'モバイルオーダー',
            foregroundColor: Color(0xFF00796B),
            backgroundColor: Color(0xFFE0F2F1),
            borderColor: Color(0xFF80CBC4),
          ),
        if (requiresPrioritySeating)
          const _CompactBadge(
            icon: Icons.event_available_outlined,
            label: 'プライオリティ・シーティング',
            foregroundColor: Color(0xFFC62828),
            backgroundColor: Color(0xFFFFEBEE),
            borderColor: Color(0xFFEF9A9A),
          ),
      ],
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final style = FacilityVisualStyle.categoryStyle(facility);

    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 15, color: style.foregroundColor),
          const SizedBox(width: 5),
          Text(
            style.label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: style.foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaBadge extends StatelessWidget {
  const _AreaBadge({required this.areaId});

  final String areaId;

  @override
  Widget build(BuildContext context) {
    final style = FacilityVisualStyle.areaStyle(areaId);

    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 15, color: style.foregroundColor),
          const SizedBox(width: 5),
          Text(
            style.label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: style.foregroundColor,
              fontWeight: FontWeight.w600,
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
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foregroundColor),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OperatingStatusBadge extends StatelessWidget {
  const _OperatingStatusBadge({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final style = _style;

    return _CompactBadge(
      icon: style.icon,
      label: facility.operatingStatusDisplayLabel,
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
  const _DetailsToggle({required this.isExpanded, required this.onPressed});

  final bool isExpanded;
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
          child: const Icon(Icons.keyboard_arrow_down, size: 19),
        ),
        label: Text(isExpanded ? '詳細を閉じる' : '詳細を見る'),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _FacilityDetails extends StatelessWidget {
  const _FacilityDetails({
    required this.facility,
    required this.showOperatingStatus,
  });

  final Facility facility;
  final bool showOperatingStatus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showOperatingStatus) _OperatingStatusDetails(facility: facility),
          if (facility.isShowRestaurant &&
              facility.showName != null &&
              facility.showName!.trim().isNotEmpty) ...[
            if (showOperatingStatus) const SizedBox(height: AppSpacing.sm),
            _DetailRow(
              icon: Icons.theater_comedy_outlined,
              label: facility.showName!,
              emphasized: true,
            ),
          ],
          if (facility.primaryProductLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
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
            const SizedBox(height: AppSpacing.xs),
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
            const SizedBox(height: AppSpacing.sm),
            Text(
              facility.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
          if (facility.hasMenuUrl || facility.hasOfficialUrl) ...[
            const SizedBox(height: AppSpacing.sm),
            _FacilityLinks(facility: facility),
          ],
        ],
      ),
    );
  }
}

class _OperatingStatusDetails extends StatelessWidget {
  const _OperatingStatusDetails({required this.facility});

  final Facility facility;

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
      padding: const EdgeInsets.all(9),
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
  const _FacilityLinks({required this.facility});

  final Facility facility;

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
              minimumSize: const Size(0, 34),
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
              minimumSize: const Size(0, 34),
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
