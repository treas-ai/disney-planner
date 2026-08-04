import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/dependency/service_locator.dart';
import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/entities/wish_item.dart';
import '../../domain/enums/wish_item_category.dart';
import 'wish_list_controller.dart';

class WishListScreen extends StatefulWidget {
  const WishListScreen({
    super.key,
    required this.onCandidateReviewPressed,
  });

  final VoidCallback onCandidateReviewPressed;

  @override
  State<WishListScreen> createState() => _WishListScreenState();
}

class _WishListScreenState extends State<WishListScreen> {
  WishListController? _controller;
  final TextEditingController _searchController = TextEditingController();

  WishListController get controller => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= WishListController(
      appState: AppStateScope.of(context),
      facilityRepository: ServiceLocator.facilityRepository,
    )..load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _applyToPlan() async {
    final added = await controller.applySelectedItemsToPlan();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added == 0
              ? '対象店舗はすでにプラン候補へ追加されています。'
              : '$added店舗をプラン候補へ追加しました。',
        ),
      ),
    );
    widget.onCandidateReviewPressed();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([controller, appState]),
      builder: (context, child) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = controller.visibleItems;

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'やりたいことリスト',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '飲みたい・食べたい・買いたいものを選び、'
                      '販売店舗をまとめてプランへ反映します。',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        FilledButton.icon(
                          onPressed:
                              controller.selectAllEligibleFreeDrinkMenus,
                          icon: const Icon(Icons.local_drink_outlined),
                          label: const Text(
                            'フリードリンク券で楽しめる特別メニューをすべて選択',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _applyToPlan,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('選択内容を反映して候補確認へ'),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.isRefreshing
                              ? null
                              : controller.refreshRemote,
                          icon: const Icon(Icons.cloud_download_outlined),
                          label: const Text('イベント情報を更新'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      '対象にはスペシャルドリンク、カフェ系ドリンク、'
                      'ジュース、スープ、ドリンクジュレを含みます。'
                      'ただし、メニューが販売されていても、'
                      'フリードリンク券の対象とは限りません。'
                      'クリスタルパレス・レストランなどの対象外店舗は'
                      '一括選択に含めません。最終確認は公式アプリの'
                      '「フリードリンク」フィルターをご利用ください。',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _searchController,
              onChanged: controller.setQuery,
              decoration: const InputDecoration(
                labelText: 'メニュー名・店舗名を検索',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                FilterChip(
                  label: const Text('すべて'),
                  selected: controller.categoryFilter == null,
                  onSelected: (_) => controller.setCategory(null),
                ),
                for (final category in WishItemCategory.values)
                  FilterChip(
                    label: Text(category.label),
                    selected: controller.categoryFilter == category,
                    onSelected: (_) => controller.setCategory(category),
                  ),
                FilterChip(
                  label: const Text('フリードリンク対象のみ'),
                  selected: controller.freeDrinkOnly,
                  onSelected: controller.setFreeDrinkOnly,
                ),
              ],
            ),
            if (controller.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                controller.errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${items.length}件表示・未完了選択 ${appState.selectedWishCount}件',
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final item in items) ...[
              _WishItemCard(item: item),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
        );
      },
    );
  }
}

class _WishItemCard extends StatelessWidget {
  const _WishItemCard({required this.item});

  final WishItem item;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final state = appState.wishStateFor(item.id);
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: state.selected,
              onChanged: (value) {
                appState.toggleWishSelected(item.id, value ?? false);
              },
              title: Text(
                item.name,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  decoration:
                      state.completed ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text(
                '${item.category.label}・${item.venueNames.join('／')}',
              ),
              secondary: Icon(
                switch (item.category) {
                  WishItemCategory.specialDrink =>
                    Icons.local_drink_outlined,
                  WishItemCategory.cafeDrink => Icons.coffee_outlined,
                  WishItemCategory.juice => Icons.local_cafe_outlined,
                  WishItemCategory.soup => Icons.soup_kitchen_outlined,
                  WishItemCategory.drinkJelly => Icons.bubble_chart_outlined,
                  _ => Icons.favorite_border,
                },
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (item.freeDrinkEligible)
                  Chip(
                    avatar: const Icon(Icons.check_circle_outline, size: 17),
                    label: const Text('フリードリンク対象'),
                  ),
                if (item.mobileOrder)
                  const Chip(label: Text('モバイルオーダー')),
                Chip(
                  label: Text(
                    '${item.startDate.month}/${item.startDate.day}'
                    '～${item.endDate.month}/${item.endDate.day}',
                  ),
                ),
                if (item.priceYen != null)
                  Chip(label: Text('¥${item.priceYen}')),
              ],
            ),
            if (item.description != null) ...[
              const SizedBox(height: 6),
              Text(item.description!),
            ],
            if (item.freeDrinkEligibilityNote != null) ...[
              const SizedBox(height: 6),
              Text(
                item.freeDrinkEligibilityNote!,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('優先度'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: state.priority,
                  items: List.generate(
                    5,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text('★' * (index + 1)),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      appState.updateWishPriority(item.id, value);
                    }
                  },
                ),
                const Spacer(),
                FilterChip(
                  selected: state.completed,
                  label: const Text('完了'),
                  avatar: const Icon(Icons.done, size: 17),
                  onSelected: (value) {
                    appState.toggleWishCompleted(item.id, value);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
