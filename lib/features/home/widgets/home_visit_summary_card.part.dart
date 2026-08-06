part of '../home_screen.dart';

class _VisitSummaryCard extends StatelessWidget {
  const _VisitSummaryCard({
    required this.settings,
    required this.onSettingsPressed,
  });

  final TripSettings settings;
  final VoidCallback onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    final enabledServices = <String>[
      if (settings.hasHappyEntry) 'ハッピーエントリー',
      if (settings.canUseDpa) 'DPA',
      if (settings.canUsePriorityPass) 'プライオリティパス',
      if (settings.canUseSingleRider) 'シングルライダー',
    ];

    final meals = <String>[
      if (settings.wantsBreakfast) '朝食',
      if (settings.wantsLunch) '昼食',
      if (settings.wantsDinner) '夕食',
    ];

    final conditions = <String>[
      if (settings.isRainy) '雨天',
      if (settings.hasChildren) '子ども連れ',
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeCardHeader(
            title: '来園設定',
            icon: Icons.tune_outlined,
            actionLabel: '編集する',
            actionIcon: Icons.edit_outlined,
            onActionPressed: onSettingsPressed,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SummaryRow(
            icon: Icons.login,
            title: '入園',
            value: settings.entryTimeLabel,
          ),
          _SummaryRow(
            icon: Icons.logout,
            title: '退園',
            value: settings.exitTimeLabel,
          ),
          _SummaryRow(
            icon: Icons.groups_outlined,
            title: '人数',
            value: '${settings.numberOfPeople}人',
          ),
          _SummaryRow(
            icon: Icons.confirmation_number_outlined,
            title: '利用サービス',
            value: enabledServices.isEmpty
                ? '利用しない'
                : enabledServices.join('・'),
          ),
          _SummaryRow(
            icon: Icons.restaurant_outlined,
            title: '食事',
            value: meals.isEmpty ? '設定なし' : meals.join('・'),
          ),
          _SummaryRow(
            icon: Icons.info_outline,
            title: '条件',
            value: conditions.isEmpty ? '特になし' : conditions.join('・'),
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _SelectedFacilitySummaryCard extends StatelessWidget {
  const _SelectedFacilitySummaryCard({
    required this.selectedFacilities,
    required this.unavailableFacilities,
    required this.onEditPlanPressed,
  });

  final List<Facility> selectedFacilities;
  final List<Facility> unavailableFacilities;
  final VoidCallback onEditPlanPressed;

  @override
  Widget build(BuildContext context) {
    final categoryCounts = <String, int>{};

    for (final facility in selectedFacilities) {
      final label = _categoryLabel(facility);

      categoryCounts[label] = (categoryCounts[label] ?? 0) + 1;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeCardHeader(
            title: '選択済み施設',
            icon: Icons.playlist_add_check_outlined,
            trailing: '${selectedFacilities.length}件',
            actionLabel: selectedFacilities.isEmpty ? '施設を追加' : '編集する',
            actionIcon: selectedFacilities.isEmpty
                ? Icons.add_outlined
                : Icons.edit_outlined,
            onActionPressed: onEditPlanPressed,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (selectedFacilities.isEmpty)
            Text(
              'まだ候補はありません。AI質問から、やりたいことを選びましょう。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in categoryCounts.entries)
                  _CountBadge(label: entry.key, count: entry.value),
              ],
            ),
            if (unavailableFacilities.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${unavailableFacilities.length}件は休止中または追加不可です。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _categoryLabel(Facility facility) {
    if (facility.isShop) {
      return 'ショップ';
    }

    if (facility.isRestaurant) {
      return 'レストラン';
    }

    return switch (facility.category.name) {
      'attraction' => 'アトラクション',
      'show' => 'ショー・パレード',
      'parade' => 'ショー・パレード',
      'greeting' => 'グリーティング',
      'service' => 'サービス',
      _ => facility.category.label,
    };
  }
}

