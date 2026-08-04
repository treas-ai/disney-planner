import 'package:flutter/material.dart';

import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../facility/facility_browser_screen.dart';

class PlanEditorScreen extends StatelessWidget {
  const PlanEditorScreen({
    super.key,
    required this.searchController,
    required this.onReviewPlanPressed,
  });

  final TextEditingController searchController;
  final VoidCallback onReviewPlanPressed;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final selectedCount = appState.selectedFacilityCountForPark(
      appState.tripSettings.parkId,
    );

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.checklist_outlined,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  selectedCount == 0
                      ? 'Wish Listから反映した店舗・施設がありません。'
                        '必要な施設を手動で追加してください。'
                      : 'Wish Listと手動選択から、$selectedCount件を'
                        'プラン候補にしています。不要な施設の削除や'
                        '追加を行ってからプランを生成してください。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FacilityBrowserScreen(
            searchController: searchController,
            onReviewPlanPressed: onReviewPlanPressed,
          ),
        ),
      ],
    );
  }
}
