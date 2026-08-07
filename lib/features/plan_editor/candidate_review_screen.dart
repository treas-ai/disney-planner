import 'package:flutter/material.dart';

import '../../app/dependency/service_locator.dart';
import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../domain/entities/facility.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/enums/fixed_time_status.dart';
import '../../domain/enums/priority_level.dart';
import '../facility/plan_builder_controller.dart';
import '../facility/plan_preference_controller.dart';
import '../facility/widgets/plan_preference_editor.dart';
import '../wish_list/wish_list_controller.dart';

class CandidateReviewScreen extends StatefulWidget {
  const CandidateReviewScreen({
    super.key,
    required this.onWishListPressed,
  });

  final VoidCallback onWishListPressed;

  @override
  State<CandidateReviewScreen> createState() => _CandidateReviewScreenState();
}

class _CandidateReviewScreenState extends State<CandidateReviewScreen> {
  PlanBuilderController? _builderController;
  PlanPreferenceController? _preferenceController;
  WishListController? _wishListController;
  String _selectedCategory = 'attraction';
  String _filter = 'all';
  final ScrollController _candidateScrollController = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_builderController != null) {
      return;
    }

    final appState = AppStateScope.of(context);
    _builderController = PlanBuilderController(appState)..addListener(_refresh);
    _preferenceController = PlanPreferenceController(appState)
      ..addListener(_refresh);
    _wishListController = WishListController(
      appState: appState,
      facilityRepository: ServiceLocator.facilityRepository,
    )
      ..addListener(_refresh)
      ..load();
  }

  @override
  void dispose() {
    _builderController?.removeListener(_refresh);
    _preferenceController?.removeListener(_refresh);
    _builderController?.dispose();
    _preferenceController?.dispose();
    _wishListController?.removeListener(_refresh);
    _wishListController?.dispose();
    _candidateScrollController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _resetCandidates() async {
    final appState = AppStateScope.of(context);
    final parkId = appState.tripSettings.parkId;
    final count = appState.selectedFacilityCountForPark(parkId);
    if (count == 0) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI候補をリセットしますか？'),
        content: Text(
          '$count件の候補と施設ごとの詳細設定を削除します。\n'
          '「やりたいこと」の回答は残るため、戻って再抽出できます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('候補をリセット'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      appState.clearSelectedFacilitiesForPark(parkId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final parkId = appState.tripSettings.parkId;
    final allCandidates = appState.selectedFacilitiesForPark(parkId);
    final preferenceController = _preferenceController;
    final wishListController = _wishListController;

    if (preferenceController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final categories = <_ReviewCategory>[
      _ReviewCategory(
        id: 'attraction',
        label: 'アトラクション',
        icon: Icons.attractions_outlined,
        facilities: allCandidates
            .where((f) => f.category == FacilityCategory.attraction)
            .toList(growable: false),
      ),
      _ReviewCategory(
        id: 'show',
        label: 'ショー・パレード',
        icon: Icons.theater_comedy_outlined,
        facilities: allCandidates
            .where(
              (f) =>
                  f.category == FacilityCategory.show ||
                  f.category == FacilityCategory.parade,
            )
            .toList(growable: false),
      ),
      _ReviewCategory(
        id: 'food',
        label: 'フード・ドリンク',
        icon: Icons.restaurant_outlined,
        facilities: allCandidates
            .where(
              (f) =>
                  f.category == FacilityCategory.restaurant ||
                  f.category == FacilityCategory.shop ||
                  f.category == FacilityCategory.service,
            )
            .toList(growable: false),
      ),
      _ReviewCategory(
        id: 'greeting',
        label: 'グリーティング',
        icon: Icons.emoji_people_outlined,
        facilities: allCandidates
            .where((f) => f.category == FacilityCategory.greeting)
            .toList(growable: false),
      ),
    ];

    if (!categories.any((category) => category.id == _selectedCategory)) {
      _selectedCategory = categories.first.id;
    }

    final selectedCategory = categories.firstWhere(
      (category) => category.id == _selectedCategory,
    );
    final visibleCandidates = selectedCategory.facilities.where((facility) {
      final priority = appState.getPreference(facility.id)?.priority;
      return switch (_filter) {
        'must' => priority == PriorityLevel.high || priority == PriorityLevel.highest,
        'normal' => priority == PriorityLevel.medium || priority == PriorityLevel.low,
        _ => true,
      };
    }).toList(growable: false);

    final mustCount = allCandidates.where((facility) {
      final priority = appState.getPreference(facility.id)?.priority;
      return priority == PriorityLevel.high || priority == PriorityLevel.highest;
    }).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;

        if (allCandidates.isEmpty) {
          return _NoCandidatesPage(
            compact: compact,
            onWishListPressed: widget.onWishListPressed,
          );
        }

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                compact ? AppSpacing.xs : AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: _ReviewIntroduction(
                selectedWishCount: appState.selectedWishCount,
                candidateOptionCount:
                    wishListController?.selectedCandidateOptionCount ??
                    allCandidates.length,
                candidateCount: allCandidates.length,
                mustCount: mustCount,
                compact: compact,
                onResetPressed: _resetCandidates,
              ),
            ),
            SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _CategoryTabs(
                categories: categories,
                selectedId: _selectedCategory,
                compact: compact,
                onSelected: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                  if (_candidateScrollController.hasClients) {
                    _candidateScrollController.jumpTo(0);
                  }
                },
              ),
            ),
            SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _ReviewFilters(
                value: _filter,
                compact: compact,
                onChanged: (value) {
                  setState(() {
                    _filter = value;
                  });
                  if (_candidateScrollController.hasClients) {
                    _candidateScrollController.jumpTo(0);
                  }
                },
              ),
            ),
            SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
            Expanded(
              child: visibleCandidates.isEmpty
                  ? _EmptyCandidates(hasAnyCandidate: true)
                  : Scrollbar(
                      controller: _candidateScrollController,
                      thumbVisibility: compact,
                      trackVisibility: compact,
                      interactive: true,
                      child: ListView.separated(
                        controller: _candidateScrollController,
                        primary: false,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        itemCount: visibleCandidates.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final facility = visibleCandidates[index];
                          return _CandidateCard(
                            facility: facility,
                            preferenceController: preferenceController,
                            onRemove: () =>
                                _builderController?.removeFacility(facility.id),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ReviewIntroduction extends StatelessWidget {
  const _ReviewIntroduction({
    required this.selectedWishCount,
    required this.candidateOptionCount,
    required this.candidateCount,
    required this.mustCount,
    required this.compact,
    required this.onResetPressed,
  });

  final int selectedWishCount;
  final int candidateOptionCount;
  final int candidateCount;
  final int mustCount;
  final bool compact;
  final VoidCallback onResetPressed;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      'AI候補を最終調整',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );

    final resetButton = OutlinedButton.icon(
      onPressed: candidateCount == 0 ? null : onResetPressed,
      icon: const Icon(Icons.restart_alt, size: 18),
      label: Text(compact ? 'リセット' : '候補をリセット'),
    );

    return AppCard(
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: title),
                    resetButton,
                  ],
                ),
                const SizedBox(height: 6),
                _CandidateCountSummary(
                  selectedWishCount: selectedWishCount,
                  candidateOptionCount: candidateOptionCount,
                  candidateCount: candidateCount,
                  compact: true,
                ),
                const SizedBox(height: 6),
                Text(
                  'プランには選んだ体験をそのまま大量追加しません。'
                  '複数店舗で利用できる商品は、候補枠を保持したまま移動しやすい1店舗へ絞ります。'
                  '${mustCount > 0 ? ' 最優先は$mustCount件です。' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 4),
                      _CandidateCountSummary(
                        selectedWishCount: selectedWishCount,
                        candidateOptionCount: candidateOptionCount,
                        candidateCount: candidateCount,
                        compact: false,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '候補枠はAIが比較できる選択肢です。対象施設が候補枠より少ないのは、'
                        '同じ店舗が複数の商品候補に含まれているためです。'
                        '実際のプランでは、前後の予定と移動に合わせて最適な店舗だけを採用します。'
                        ' 最優先にしたい体験は優先度を高くし、不要な候補だけ削除してください。'
                        '${mustCount > 0 ? ' 現在の最優先候補は$mustCount件です。' : ''}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                resetButton,
              ],
            ),
    );
  }
}


class _CandidateCountSummary extends StatelessWidget {
  const _CandidateCountSummary({
    required this.selectedWishCount,
    required this.candidateOptionCount,
    required this.candidateCount,
    required this.compact,
  });

  final int selectedWishCount;
  final int candidateOptionCount;
  final int candidateCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _CountBadge(label: 'やりたいこと', count: selectedWishCount),
      const Icon(Icons.arrow_forward, size: 16),
      _CountBadge(label: '候補枠', count: candidateOptionCount),
      const Icon(Icons.arrow_forward, size: 16),
      _CountBadge(label: '対象施設', count: candidateCount),
    ];

    if (compact) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: items,
      );
    }
    return Row(children: items);
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        '$label $count件',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.categories,
    required this.selectedId,
    required this.compact,
    required this.onSelected,
  });

  final List<_ReviewCategory> categories;
  final String selectedId;
  final bool compact;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          primary: false,
          clipBehavior: Clip.hardEdge,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemCount: categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final category = categories[index];
            return _CategoryTabButton(
              category: category,
              selected: selectedId == category.id,
              compact: true,
              onPressed: () => onSelected(category.id),
            );
          },
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((category) {
            return SizedBox(
              width: constraints.maxWidth >= 900
                  ? (constraints.maxWidth - 24) / 4
                  : (constraints.maxWidth - 8) / 2,
              child: _CategoryTabButton(
                category: category,
                selected: selectedId == category.id,
                compact: false,
                onPressed: () => onSelected(category.id),
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

class _CategoryTabButton extends StatelessWidget {
  const _CategoryTabButton({
    required this.category,
    required this.selected,
    required this.compact,
    required this.onPressed,
  });

  final _ReviewCategory category;
  final bool selected;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final content = Row(
      children: [
        Icon(
          category.icon,
          size: compact ? 17 : 18,
          color: selected ? colors.primary : colors.onSurfaceVariant,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            category.label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Container(
          height: 24,
          constraints: const BoxConstraints(minWidth: 24),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? colors.primary
                : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${category.facilities.length}',
            maxLines: 1,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected
                  ? colors.onPrimary
                  : colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

    return SizedBox(
      width: compact ? 188 : double.infinity,
      height: compact ? 48 : 46,
      child: Material(
        color: selected
            ? colors.primaryContainer
            : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _ReviewFilters extends StatelessWidget {
  const _ReviewFilters({
    required this.value,
    required this.compact,
    required this.onChanged,
  });

  final String value;
  final bool compact;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      return SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: 'all',
            label: Text('すべて'),
            icon: Icon(Icons.list_alt),
          ),
          ButtonSegment(
            value: 'must',
            label: Text('最優先'),
            icon: Icon(Icons.star_outline),
          ),
          ButtonSegment(
            value: 'normal',
            label: Text('行きたい'),
            icon: Icon(Icons.check_circle_outline),
          ),
        ],
        selected: {value},
        showSelectedIcon: false,
        onSelectionChanged: (values) => onChanged(values.first),
      );
    }

    return SizedBox(
      height: 42,
      child: Row(
        children: [
          Expanded(
            child: _CompactFilterButton(
              label: 'すべて',
              selected: value == 'all',
              onPressed: () => onChanged('all'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _CompactFilterButton(
              label: '最優先',
              selected: value == 'must',
              onPressed: () => onChanged('must'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _CompactFilterButton(
              label: '行きたい',
              selected: value == 'normal',
              onPressed: () => onChanged('normal'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactFilterButton extends StatelessWidget {
  const _CompactFilterButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: selected ? colors.primaryContainer : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? colors.primary : colors.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.facility,
    required this.preferenceController,
    required this.onRemove,
  });

  final Facility facility;
  final PlanPreferenceController preferenceController;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final preference = preferenceController.getPreference(facility.id);
    if (preference == null) {
      return const SizedBox.shrink();
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: CircleAvatar(child: Icon(_categoryIcon(facility.category), size: 19)),
        title: Text(
          facility.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Wrap(
            spacing: 8,
            runSpacing: 5,
            children: [
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(preference.priority.stars),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(_priorityLabel(preference.priority)),
              ),
              if (facility.supportsDpa)
                const Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('DPA対応'),
                ),
            ],
          ),
        ),
        trailing: IconButton(
          tooltip: '候補から削除',
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_reasonFor(facility, preference.priority)),
          ),
          const SizedBox(height: AppSpacing.sm),
          PlanPreferenceEditor(
            facility: facility,
            preference: preference,
            vacationPackageEnabled: appState.tripSettings.usesVacationPackage,
            vacationPackageShowVoucherEnabled:
                appState.tripSettings.hasShowVoucher,
            vacationPackageRestaurantEnabled:
                appState.tripSettings.hasRestaurantReservation,
            visitDate: appState.tripSettings.visitDate,
            onPriorityChanged: (value) => preferenceController.updatePriority(
              facilityId: facility.id,
              priority: value,
            ),
            onPreferredTimeChanged: (value) => preferenceController.updatePreferredTime(
              facilityId: facility.id,
              preferredTime: value,
            ),
            onWaitToleranceChanged: (value) => preferenceController.updateWaitTolerance(
              facilityId: facility.id,
              waitTolerance: value,
            ),
            onMealPreferenceChanged: (value) => preferenceController.updateMealPreference(
              facilityId: facility.id,
              mealPreference: value,
            ),
            onAccessMethodChanged: (value) => preferenceController.updateAccessMethod(
              facilityId: facility.id,
              accessMethod: value,
            ),
            onPreferredPerformanceTimeChanged: (value) =>
                preferenceController.updatePreferredPerformanceTime(
              facilityId: facility.id,
              value: value,
            ),
            onReservationTimeChanged: (value) {
              preferenceController.updateReservationTime(
                facilityId: facility.id,
                value: value,
              );
              preferenceController.updateFixedTimeStatus(
                facilityId: facility.id,
                status: value.trim().isEmpty
                    ? FixedTimeStatus.none
                    : FixedTimeStatus.confirmed,
              );
            },
            onScheduledAccessTimeChanged: (value) {
              preferenceController.updateScheduledAccessTime(
                facilityId: facility.id,
                value: value,
              );
              preferenceController.updateFixedTimeStatus(
                facilityId: facility.id,
                status: value.trim().isEmpty
                    ? FixedTimeStatus.none
                    : FixedTimeStatus.confirmed,
              );
            },
            onLotteryFallbackActionChanged: (value) =>
                preferenceController.updateLotteryFallbackAction(
              facilityId: facility.id,
              action: value,
            ),
            onUseDpaChanged: (value) => preferenceController.updateUseDpa(
              facilityId: facility.id,
              value: value,
            ),
            onUsePriorityPassChanged: (value) =>
                preferenceController.updateUsePriorityPass(
              facilityId: facility.id,
              value: value,
            ),
            onUseStandbyPassChanged: (value) =>
                preferenceController.updateUseStandbyPass(
              facilityId: facility.id,
              value: value,
            ),
            onPrioritizeCapsuleToyChanged: (value) =>
                preferenceController.updatePrioritizeCapsuleToy(
              facilityId: facility.id,
              value: value,
            ),
            onMemoChanged: (value) => preferenceController.updateMemo(
              facilityId: facility.id,
              memo: value,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoCandidatesPage extends StatefulWidget {
  const _NoCandidatesPage({
    required this.compact,
    required this.onWishListPressed,
  });

  final bool compact;
  final VoidCallback onWishListPressed;

  @override
  State<_NoCandidatesPage> createState() => _NoCandidatesPageState();
}

class _NoCandidatesPageState extends State<_NoCandidatesPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: widget.compact,
      child: SingleChildScrollView(
        controller: _scrollController,
        primary: false,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AppCard(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? AppSpacing.sm : AppSpacing.lg,
                  vertical: widget.compact ? AppSpacing.lg : 40,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: widget.compact ? 44 : 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'AI候補がありません',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      '「やりたいこと」で希望を選び、AI候補を作成してください。',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: widget.onWishListPressed,
                        icon: const Icon(Icons.favorite_border),
                        label: const Text('やりたいことへ戻る'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCandidates extends StatelessWidget {
  const _EmptyCandidates({required this.hasAnyCandidate});

  final bool hasAnyCandidate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              hasAnyCandidate ? 'この条件の候補はありません' : 'AI候補がまだありません',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              hasAnyCandidate
                  ? 'カテゴリまたは表示条件を切り替えてください。'
                  : '「やりたいこと」で質問に答え、候補を抽出してください。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCategory {
  const _ReviewCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.facilities,
  });

  final String id;
  final String label;
  final IconData icon;
  final List<Facility> facilities;
}

IconData _categoryIcon(FacilityCategory category) {
  return switch (category) {
    FacilityCategory.attraction => Icons.attractions_outlined,
    FacilityCategory.show || FacilityCategory.parade => Icons.theater_comedy_outlined,
    FacilityCategory.restaurant => Icons.restaurant_outlined,
    FacilityCategory.greeting => Icons.emoji_people_outlined,
    FacilityCategory.shop => Icons.local_mall_outlined,
    FacilityCategory.service => Icons.info_outline,
  };
}

String _priorityLabel(PriorityLevel priority) {
  return switch (priority) {
    PriorityLevel.highest || PriorityLevel.high => '最優先',
    PriorityLevel.medium => '行きたい',
    PriorityLevel.low || PriorityLevel.lowest => '余裕があれば',
  };
}

String _reasonFor(Facility facility, PriorityLevel priority) {
  final parts = <String>[
    '「やりたいこと」の回答と現在の優先度から候補に入りました。',
    if (priority == PriorityLevel.highest || priority == PriorityLevel.high)
      '最優先の体験としてスケジュールを優先します。',
    if (facility.supportsDpa) 'DPAの利用可否を詳細設定で調整できます。',
    if (facility.supportsPriorityPass) 'プライオリティパスの利用候補です。',
  ];
  return parts.join('\n');
}
