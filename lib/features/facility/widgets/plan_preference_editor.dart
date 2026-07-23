import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/facility.dart';
import '../../../domain/entities/plan_preference.dart';
import '../../../domain/enums/facility_category.dart';
import '../../../domain/enums/meal_preference.dart';
import '../../../domain/enums/preferred_time.dart';
import '../../../domain/enums/priority_level.dart';
import '../../../domain/enums/wait_tolerance.dart';

class PlanPreferenceEditor extends StatelessWidget {
  const PlanPreferenceEditor({
    super.key,
    required this.facility,
    required this.preference,
    required this.onPriorityChanged,
    required this.onPreferredTimeChanged,
    required this.onWaitToleranceChanged,
    required this.onMealPreferenceChanged,
    required this.onUseDpaChanged,
    required this.onUsePriorityPassChanged,
    required this.onUseStandbyPassChanged,
    required this.onPrioritizeCapsuleToyChanged,
    required this.onMemoChanged,
  });

  final Facility facility;
  final PlanPreference preference;

  final ValueChanged<PriorityLevel> onPriorityChanged;

  final ValueChanged<PreferredTime> onPreferredTimeChanged;

  final ValueChanged<WaitTolerance> onWaitToleranceChanged;

  final ValueChanged<MealPreference> onMealPreferenceChanged;

  final ValueChanged<bool> onUseDpaChanged;

  final ValueChanged<bool> onUsePriorityPassChanged;

  final ValueChanged<bool> onUseStandbyPassChanged;

  final ValueChanged<bool> onPrioritizeCapsuleToyChanged;

  final ValueChanged<String> onMemoChanged;

  bool get _isRestaurant {
    return facility.category == FacilityCategory.restaurant;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(facility.name, style: Theme.of(context).textTheme.titleLarge),
          if (facility.isRestaurant) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'レストラン種別：'
              '${facility.restaurantType.label}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (facility.isShop) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'ショップ種別：'
              '${facility.shopType.label}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<PriorityLevel>(
            key: ValueKey(
              '${facility.id}_'
              'priority_'
              '${preference.priority.name}',
            ),
            initialValue: preference.priority,
            decoration: const InputDecoration(
              labelText: '優先度',
              border: OutlineInputBorder(),
            ),
            items: PriorityLevel.values
                .map(
                  (priority) => DropdownMenuItem(
                    value: priority,
                    child: Text(
                      '${priority.label} '
                      '${priority.stars}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onPriorityChanged(value);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<PreferredTime>(
            key: ValueKey(
              '${facility.id}_'
              'preferred_time_'
              '${preference.preferredTime.name}',
            ),
            initialValue: preference.preferredTime,
            decoration: const InputDecoration(
              labelText: '希望時間',
              border: OutlineInputBorder(),
            ),
            items: PreferredTime.values
                .map(
                  (time) =>
                      DropdownMenuItem(value: time, child: Text(time.label)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onPreferredTimeChanged(value);
              }
            },
          ),
          if (_isRestaurant) ...[
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<MealPreference>(
              key: ValueKey(
                '${facility.id}_'
                'meal_'
                '${preference.mealPreference.name}',
              ),
              initialValue: preference.mealPreference,
              decoration: const InputDecoration(
                labelText: '食事利用',
                helperText:
                    '予約時間が登録されている場合は、'
                    '予約時間を優先します。',
                border: OutlineInputBorder(),
              ),
              items: MealPreference.values
                  .map(
                    (meal) =>
                        DropdownMenuItem(value: meal, child: Text(meal.label)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onMealPreferenceChanged(value);
                }
              },
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<WaitTolerance>(
            key: ValueKey(
              '${facility.id}_'
              'wait_'
              '${preference.waitTolerance.name}',
            ),
            initialValue: preference.waitTolerance,
            decoration: const InputDecoration(
              labelText: '待ち時間許容',
              helperText:
                  '優先度が高い施設は、許容時間を超えても'
                  '理由を表示して候補に残す場合があります。',
              border: OutlineInputBorder(),
            ),
            items: WaitTolerance.values
                .map(
                  (tolerance) => DropdownMenuItem(
                    value: tolerance,
                    child: Text(tolerance.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onWaitToleranceChanged(value);
              }
            },
          ),
          if (facility.supportsDpa) ...[
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ディズニー・プレミアアクセスを使う'),
              subtitle: const Text(
                'ディズニー・プレミアアクセスを'
                '利用する前提で予定を作成します。',
              ),
              value: preference.useDpa,
              onChanged: onUseDpaChanged,
            ),
          ],
          if (facility.supportsPriorityPass) ...[
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('プライオリティパスを使う'),
              subtitle: const Text(
                '東京ディズニーリゾート40周年記念'
                'プライオリティパスを利用する前提で'
                '予定を作成します。',
              ),
              value: preference.usePriorityPass,
              onChanged: onUsePriorityPassChanged,
            ),
          ],
          if (facility.supportsStandbyPass) ...[
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('スタンバイパスを使う'),
              subtitle: const Text(
                '当日に発行されている場合、'
                'スタンバイパスの利用を優先します。',
              ),
              value: preference.useStandbyPass,
              onChanged: onUseStandbyPassChanged,
            ),
          ],
          if (facility.isCapsuleToy) ...[
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('カプセルトイを優先する'),
              subtitle: const Text(
                '通常のショップより早い時間帯への'
                '配置を優先します。',
              ),
              value: preference.prioritizeCapsuleToy,
              onChanged: onPrioritizeCapsuleToyChanged,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            key: ValueKey(
              '${facility.id}_'
              '${preference.memo}',
            ),
            initialValue: preference.memo,
            decoration: const InputDecoration(
              labelText: 'メモ',
              border: OutlineInputBorder(),
            ),
            minLines: 1,
            maxLines: 3,
            onChanged: onMemoChanged,
          ),
        ],
      ),
    );
  }
}
