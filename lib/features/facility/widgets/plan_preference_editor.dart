import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/facility.dart';
import '../../../domain/entities/plan_preference.dart';
import '../../../domain/enums/facility_access_method.dart';
import '../../../domain/enums/facility_category.dart';
import '../../../domain/enums/lottery_fallback_action.dart';
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
    required this.onAccessMethodChanged,
    required this.onPreferredPerformanceTimeChanged,
    required this.onReservationTimeChanged,
    required this.onScheduledAccessTimeChanged,
    required this.onLotteryFallbackActionChanged,
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
  final ValueChanged<FacilityAccessMethod> onAccessMethodChanged;
  final ValueChanged<String> onPreferredPerformanceTimeChanged;
  final ValueChanged<String> onReservationTimeChanged;
  final ValueChanged<String> onScheduledAccessTimeChanged;
  final ValueChanged<LotteryFallbackAction> onLotteryFallbackActionChanged;
  final ValueChanged<bool> onUseDpaChanged;
  final ValueChanged<bool> onUsePriorityPassChanged;
  final ValueChanged<bool> onUseStandbyPassChanged;
  final ValueChanged<bool> onPrioritizeCapsuleToyChanged;
  final ValueChanged<String> onMemoChanged;

  bool get _isShowOrParade {
    return facility.category == FacilityCategory.show ||
        facility.category == FacilityCategory.parade;
  }

  bool get _isRestaurant {
    return facility.isRestaurant;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(facility.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<PriorityLevel>(
            key: ValueKey(
              '${facility.id}_priority_${preference.priority.name}',
            ),
            initialValue: preference.priority,
            decoration: const InputDecoration(
              labelText: '優先度',
              border: OutlineInputBorder(),
            ),
            items: PriorityLevel.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text('${value.label} ${value.stars}'),
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
              '${facility.id}_preferred_${preference.preferredTime.name}',
            ),
            initialValue: preference.preferredTime,
            decoration: const InputDecoration(
              labelText: '希望時間',
              helperText: '固定時刻がある場合は固定時刻を優先します。',
              border: OutlineInputBorder(),
            ),
            items: PreferredTime.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
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
                '${facility.id}_meal_${preference.mealPreference.name}',
              ),
              initialValue: preference.mealPreference,
              decoration: const InputDecoration(
                labelText: '食事利用',
                border: OutlineInputBorder(),
              ),
              items: MealPreference.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
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
              '${facility.id}_wait_${preference.waitTolerance.name}',
            ),
            initialValue: preference.waitTolerance,
            decoration: const InputDecoration(
              labelText: '待ち時間許容',
              border: OutlineInputBorder(),
            ),
            items: WaitTolerance.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onWaitToleranceChanged(value);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<FacilityAccessMethod>(
            key: ValueKey(
              '${facility.id}_access_${preference.accessMethod.name}',
            ),
            initialValue: preference.accessMethod,
            decoration: const InputDecoration(
              labelText: '利用方法',
              helperText: '取得・予約済みの利用方法を選択してください。',
              border: OutlineInputBorder(),
            ),
            items: _availableAccessMethods()
                .map(
                  (method) => DropdownMenuItem(
                    value: method,
                    child: Text(_accessMethodLabel(method)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onAccessMethodChanged(value);
              }
            },
          ),
          if (preference.accessMethod == FacilityAccessMethod.entryRequest &&
              facility.requiresEntryRequest) ...[
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<LotteryFallbackAction>(
              key: ValueKey(
                '${facility.id}_fallback_${preference.lotteryFallbackAction.name}',
              ),
              initialValue: preference.lotteryFallbackAction,
              decoration: const InputDecoration(
                labelText: '外れた場合',
                border: OutlineInputBorder(),
              ),
              items: LotteryFallbackAction.values
                  .map(
                    (action) => DropdownMenuItem(
                      value: action,
                      child: Text(_fallbackLabel(action)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onLotteryFallbackActionChanged(value);
                }
              },
            ),
          ],
          if (facility.isCapsuleToy) ...[
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('カプセルトイを優先する'),
              value: preference.prioritizeCapsuleToy,
              onChanged: onPrioritizeCapsuleToyChanged,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            key: ValueKey('${facility.id}_${preference.memo}'),
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

  List<FacilityAccessMethod> _availableAccessMethods() {
    final methods = <FacilityAccessMethod>[FacilityAccessMethod.standby];

    if (facility.supportsDpa) {
      methods.add(FacilityAccessMethod.dpa);
    }

    if (facility.supportsPriorityPass) {
      methods.add(FacilityAccessMethod.priorityPass);
    }

    if (facility.supportsStandbyPass) {
      methods.add(FacilityAccessMethod.standbyPass);
    }

    if (facility.requiresEntryRequest) {
      methods.add(FacilityAccessMethod.entryRequest);
    }

    if (_isRestaurant ||
        facility.requiresReservation ||
        facility.reservationRequired ||
        facility.supportsPrioritySeating) {
      methods.add(FacilityAccessMethod.reservation);
    }

    if (_isShowOrParade) {
      methods.add(FacilityAccessMethod.freeSeating);
    }

    if (!methods.contains(preference.accessMethod)) {
      methods.add(preference.accessMethod);
    }

    return methods;
  }
}

String _accessMethodLabel(FacilityAccessMethod method) {
  return switch (method) {
    FacilityAccessMethod.standby => '通常待機・通常利用',
    FacilityAccessMethod.dpa => 'ディズニー・プレミアアクセス',
    FacilityAccessMethod.priorityPass => 'プライオリティパス',
    FacilityAccessMethod.standbyPass => 'スタンバイパス',
    FacilityAccessMethod.entryRequest => 'エントリー受付',
    FacilityAccessMethod.reservation => '予約・プライオリティ・シーティング',
    FacilityAccessMethod.freeSeating => '自由席・自由鑑賞',
  };
}

String _fallbackLabel(LotteryFallbackAction action) {
  return switch (action) {
    LotteryFallbackAction.alternativeFacility => '別の施設へ行く',
    LotteryFallbackAction.freeSeating => '自由席・自由鑑賞を利用',
    LotteryFallbackAction.retryLater => '後で再検討',
    LotteryFallbackAction.skip => 'この施設を諦める',
  };
}
