import 'package:flutter/material.dart';

import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/section_title.dart';
import '../../domain/entities/facility.dart';
import 'facility_controller.dart';
import 'plan_builder_controller.dart';
import 'plan_preference_controller.dart';
import 'widgets/facility_card.dart';
import 'widgets/facility_category_filter.dart';
import 'widgets/facility_search_field.dart';
import 'widgets/plan_preference_editor.dart';
import 'widgets/selected_facility_list.dart';

class FacilityBrowserScreen extends StatefulWidget {
  const FacilityBrowserScreen({super.key});

  @override
  State<FacilityBrowserScreen> createState() => _FacilityBrowserScreenState();
}

class _FacilityBrowserScreenState extends State<FacilityBrowserScreen> {
  FacilityController? _facilityController;
  PlanBuilderController? _planBuilderController;
  PlanPreferenceController? _planPreferenceController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_facilityController == null ||
        _planBuilderController == null ||
        _planPreferenceController == null) {
      final appState = AppStateScope.of(context);

      _facilityController = FacilityController();
      _planBuilderController = PlanBuilderController(appState);
      _planPreferenceController = PlanPreferenceController(appState);

      _facilityController!.addListener(_refresh);
      _planBuilderController!.addListener(_refresh);
      _planPreferenceController!.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    _facilityController?.removeListener(_refresh);
    _planBuilderController?.removeListener(_refresh);
    _planPreferenceController?.removeListener(_refresh);

    _facilityController?.dispose();
    _planBuilderController?.dispose();
    _planPreferenceController?.dispose();

    super.dispose();
  }

  void _refresh() {
    setState(() {});
  }

  void _addFacility(Facility facility) {
    _planBuilderController?.addFacility(facility);
  }

  void _removeFacility(String facilityId) {
    _planBuilderController?.removeFacility(facilityId);
  }

  @override
  Widget build(BuildContext context) {
    final facilityController = _facilityController;
    final planBuilderController = _planBuilderController;
    final planPreferenceController = _planPreferenceController;

    if (facilityController == null ||
        planBuilderController == null ||
        planPreferenceController == null) {
      return const AppScaffold(child: LoadingView(message: '施設画面を準備中です...'));
    }

    return AppScaffold(
      child: Builder(
        builder: (context) {
          if (facilityController.isLoading) {
            return const LoadingView(message: '施設データを読み込み中です...');
          }

          if (facilityController.errorMessage != null) {
            return EmptyState(
              title: '読み込みエラー',
              message: facilityController.errorMessage!,
              icon: Icons.error_outline,
            );
          }

          final filteredFacilities = facilityController.filteredFacilities;

          final selectedFacilities = planBuilderController.selectedFacilities;

          return ListView(
            children: [
              const SectionTitle(
                title: '施設一覧',
                subtitle: '施設を選び、希望条件を設定します。',
                icon: AppIcons.planEditorSelected,
              ),
              FacilitySearchField(
                onChanged: facilityController.updateSearchKeyword,
              ),
              FacilityCategoryFilter(
                selectedCategory: facilityController.selectedCategory,
                onSelected: facilityController.selectCategory,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  '表示件数：${filteredFacilities.length}件 / '
                  '選択済み：${planBuilderController.selectedCount}件',
                ),
              ),
              SelectedFacilityList(
                selectedFacilities: selectedFacilities,
                onRemove: _removeFacility,
              ),
              if (selectedFacilities.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('希望条件', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                for (final facility in selectedFacilities)
                  Builder(
                    builder: (context) {
                      final preference = planPreferenceController.getPreference(
                        facility.id,
                      );

                      if (preference == null) {
                        return const SizedBox.shrink();
                      }

                      return PlanPreferenceEditor(
                        facility: facility,
                        preference: preference,
                        onPriorityChanged: (priority) {
                          planPreferenceController.updatePriority(
                            facilityId: facility.id,
                            priority: priority,
                          );
                        },
                        onPreferredTimeChanged: (preferredTime) {
                          planPreferenceController.updatePreferredTime(
                            facilityId: facility.id,
                            preferredTime: preferredTime,
                          );
                        },
                        onWaitToleranceChanged: (waitTolerance) {
                          planPreferenceController.updateWaitTolerance(
                            facilityId: facility.id,
                            waitTolerance: waitTolerance,
                          );
                        },
                        onMealPreferenceChanged: (mealPreference) {
                          planPreferenceController.updateMealPreference(
                            facilityId: facility.id,
                            mealPreference: mealPreference,
                          );
                        },
                        onUseDpaChanged: (value) {
                          planPreferenceController.updateUseDpa(
                            facilityId: facility.id,
                            value: value,
                          );
                        },
                        onUsePriorityPassChanged: (value) {
                          planPreferenceController.updateUsePriorityPass(
                            facilityId: facility.id,
                            value: value,
                          );
                        },
                        onMemoChanged: (memo) {
                          planPreferenceController.updateMemo(
                            facilityId: facility.id,
                            memo: memo,
                          );
                        },
                      );
                    },
                  ),
              ],
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
                    isSelected: planBuilderController.isSelected(facility.id),
                    onAdd: () => _addFacility(facility),
                    onRemove: () => _removeFacility(facility.id),
                  ),
            ],
          );
        },
      ),
    );
  }
}
