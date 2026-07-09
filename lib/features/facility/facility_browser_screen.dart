import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/section_title.dart';
import 'facility_controller.dart';
import 'plan_builder_controller.dart';
import 'widgets/facility_card.dart';
import 'widgets/facility_category_filter.dart';
import 'widgets/facility_search_field.dart';
import 'widgets/selected_facility_list.dart';

class FacilityBrowserScreen extends StatefulWidget {
  const FacilityBrowserScreen({super.key});

  @override
  State<FacilityBrowserScreen> createState() => _FacilityBrowserScreenState();
}

class _FacilityBrowserScreenState extends State<FacilityBrowserScreen> {
  late final FacilityController _facilityController;
  late final PlanBuilderController _planBuilderController;

  @override
  void initState() {
    super.initState();
    _facilityController = FacilityController();
    _planBuilderController = PlanBuilderController();

    _facilityController.addListener(_refresh);
    _planBuilderController.addListener(_refresh);
  }

  @override
  void dispose() {
    _facilityController.removeListener(_refresh);
    _planBuilderController.removeListener(_refresh);
    _facilityController.dispose();
    _planBuilderController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Builder(
        builder: (context) {
          if (_facilityController.isLoading) {
            return const LoadingView(message: '施設データを読み込み中です...');
          }

          if (_facilityController.errorMessage != null) {
            return EmptyState(
              title: '読み込みエラー',
              message: _facilityController.errorMessage!,
              icon: Icons.error_outline,
            );
          }

          final filteredFacilities = _facilityController.filteredFacilities;

          final selectedFacilities =
              _planBuilderController.getSelectedFacilities(
            _facilityController.facilities,
          );

          return ListView(
            children: [
              const SectionTitle(
                title: '施設一覧',
                subtitle: '行きたい施設を選び、プラン候補を作成します。',
                icon: AppIcons.planEditorSelected,
              ),
              FacilitySearchField(
                onChanged: _facilityController.updateSearchKeyword,
              ),
              FacilityCategoryFilter(
                selectedCategory: _facilityController.selectedCategory,
                onSelected: _facilityController.selectCategory,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  '表示件数：${filteredFacilities.length}件 / 選択済み：${_planBuilderController.selectedCount}件',
                ),
              ),
              SelectedFacilityList(
                selectedFacilities: selectedFacilities,
                onRemove: _planBuilderController.removeFacility,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (filteredFacilities.isEmpty)
                const EmptyState(
                  title: '施設が見つかりません',
                  message: '検索条件またはカテゴリを変更してください。',
                )
              else
                for (final facility in filteredFacilities)
                  FacilityCard(
                    facility: facility,
                    isSelected: _planBuilderController.isSelected(facility.id),
                    onAdd: () => _planBuilderController.addFacility(facility),
                    onRemove: () =>
                        _planBuilderController.removeFacility(facility.id),
                  ),
            ],
          );
        },
      ),
    );
  }
}