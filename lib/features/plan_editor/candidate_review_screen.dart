import 'package:flutter/material.dart';

import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../domain/entities/facility.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/enums/priority_level.dart';
import '../facility/plan_builder_controller.dart';
import '../facility/plan_preference_controller.dart';
import '../facility/widgets/plan_preference_editor.dart';

class CandidateReviewScreen extends StatefulWidget {
  const CandidateReviewScreen({
    super.key,
    required this.onReviewPlanPressed,
  });

  final VoidCallback onReviewPlanPressed;

  @override
  State<CandidateReviewScreen> createState() => _CandidateReviewScreenState();
}

class _CandidateReviewScreenState extends State<CandidateReviewScreen> {
  PlanBuilderController? _builderController;
  PlanPreferenceController? _preferenceController;
  String _selectedCategory = 'attraction';
  String _filter = 'all';

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
  }

  @override
  void dispose() {
    _builderController?.removeListener(_refresh);
    _preferenceController?.removeListener(_refresh);
    _builderController?.dispose();
    _preferenceController?.dispose();
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: _ReviewIntroduction(
            candidateCount: allCandidates.length,
            mustCount: mustCount,
            onResetPressed: _resetCandidates,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: _CategoryTabs(
            categories: categories,
            selectedId: _selectedCategory,
            onSelected: (value) {
              setState(() {
                _selectedCategory = value;
              });
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: _ReviewFilters(
            value: _filter,
            onChanged: (value) {
              setState(() {
                _filter = value;
              });
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: visibleCandidates.isEmpty
              ? _EmptyCandidates(hasAnyCandidate: allCandidates.isNotEmpty)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    110,
                  ),
                  itemCount: visibleCandidates.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final facility = visibleCandidates[index];
                    return _CandidateCard(
                      facility: facility,
                      preferenceController: preferenceController,
                      onRemove: () => _builderController?.removeFacility(facility.id),
                    );
                  },
                ),
        ),
        _ReviewFooter(
          candidateCount: allCandidates.length,
          mustCount: mustCount,
          onPressed: allCandidates.isEmpty ? null : widget.onReviewPlanPressed,
        ),
      ],
    );
  }
}

class _ReviewIntroduction extends StatelessWidget {
  const _ReviewIntroduction({
    required this.candidateCount,
    required this.mustCount,
    required this.onResetPressed,
  });

  final int candidateCount;
  final int mustCount;
  final VoidCallback onResetPressed;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_outlined, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AIが抽出した候補を最終調整',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$candidateCount件の候補があります。最優先にしたい体験は優先度を高くし、'
                  '不要な候補だけ削除してください。詳細設定はカードを開いて編集できます。'
                  '${mustCount > 0 ? ' 現在の必須候補は$mustCount件です。' : ''}',
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: candidateCount == 0 ? null : onResetPressed,
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('候補をリセット'),
          ),
        ],
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<_ReviewCategory> categories;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((category) {
            final selected = selectedId == category.id;
            return SizedBox(
              width: constraints.maxWidth >= 900
                  ? (constraints.maxWidth - 24) / 4
                  : (constraints.maxWidth - 8) / 2,
              child: selected
                  ? FilledButton.tonalIcon(
                      onPressed: () => onSelected(category.id),
                      icon: Icon(category.icon, size: 18),
                      label: Text('${category.label} (${category.facilities.length})'),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => onSelected(category.id),
                      icon: Icon(category.icon, size: 18),
                      label: Text('${category.label} (${category.facilities.length})'),
                    ),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

class _ReviewFilters extends StatelessWidget {
  const _ReviewFilters({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'all', label: Text('すべて'), icon: Icon(Icons.list_alt)),
        ButtonSegment(value: 'must', label: Text('最優先'), icon: Icon(Icons.star_outline)),
        ButtonSegment(value: 'normal', label: Text('行きたい'), icon: Icon(Icons.check_circle_outline)),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (values) => onChanged(values.first),
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
            onReservationTimeChanged: (value) => preferenceController.updateReservationTime(
              facilityId: facility.id,
              value: value,
            ),
            onScheduledAccessTimeChanged: (value) =>
                preferenceController.updateScheduledAccessTime(
              facilityId: facility.id,
              value: value,
            ),
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

class _ReviewFooter extends StatelessWidget {
  const _ReviewFooter({
    required this.candidateCount,
    required this.mustCount,
    required this.onPressed,
  });

  final int candidateCount;
  final int mustCount;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            Expanded(child: Text('候補 $candidateCount件・最優先 $mustCount件')),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('この内容でプランを生成'),
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
