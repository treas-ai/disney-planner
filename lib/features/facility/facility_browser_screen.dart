import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/section_title.dart';
import 'facility_controller.dart';
import 'widgets/facility_card.dart';
import 'widgets/facility_category_filter.dart';
import 'widgets/facility_search_field.dart';

class FacilityBrowserScreen extends StatefulWidget {
  const FacilityBrowserScreen({super.key});

  @override
  State<FacilityBrowserScreen> createState() => _FacilityBrowserScreenState();
}

class _FacilityBrowserScreenState extends State<FacilityBrowserScreen> {
  late final FacilityController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FacilityController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const LoadingView(message: '施設データを読み込み中です...');
          }

          if (_controller.errorMessage != null) {
            return EmptyState(
              title: '読み込みエラー',
              message: _controller.errorMessage!,
              icon: Icons.error_outline,
            );
          }

          final facilities = _controller.filteredFacilities;

          return ListView(
            children: [
              const SectionTitle(
                title: '施設一覧',
                subtitle: 'パーク内の施設を検索・カテゴリ別に確認できます。',
                icon: AppIcons.planEditorSelected,
              ),
              FacilitySearchField(
                onChanged: _controller.updateSearchKeyword,
              ),
              FacilityCategoryFilter(
                selectedCategory: _controller.selectedCategory,
                onSelected: _controller.selectCategory,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text('表示件数：${facilities.length}件'),
              ),
              if (facilities.isEmpty)
                const EmptyState(
                  title: '施設が見つかりません',
                  message: '検索条件またはカテゴリを変更してください。',
                )
              else
                for (final facility in facilities)
                  FacilityCard(facility: facility),
            ],
          );
        },
      ),
    );
  }
}