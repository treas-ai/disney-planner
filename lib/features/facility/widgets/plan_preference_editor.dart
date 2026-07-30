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

  final ValueChanged<LotteryFallbackAction> onLotteryFallbackActionChanged;

  final ValueChanged<bool> onUseDpaChanged;
  final ValueChanged<bool> onUsePriorityPassChanged;
  final ValueChanged<bool> onUseStandbyPassChanged;

  final ValueChanged<bool> onPrioritizeCapsuleToyChanged;

  final ValueChanged<String> onMemoChanged;

  bool get _isRestaurant {
    return facility.category == FacilityCategory.restaurant;
  }

  bool get _isShowOrParade {
    return facility.category == FacilityCategory.show ||
        facility.category == FacilityCategory.parade;
  }

  bool get _usesEntryRequest {
    return preference.accessMethod == FacilityAccessMethod.entryRequest;
  }

  @override
  Widget build(BuildContext context) {
    final availableAccessMethods = _availableAccessMethods();

    final resolvedAccessMethod =
        availableAccessMethods.contains(preference.accessMethod)
        ? preference.accessMethod
        : availableAccessMethods.first;

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
              labelText: '希望時間帯',
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
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<FacilityAccessMethod>(
            key: ValueKey(
              '${facility.id}_'
              'access_method_'
              '${resolvedAccessMethod.name}',
            ),
            initialValue: resolvedAccessMethod,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '利用方法',
              helperText: 'この施設をどの方法で利用するか選択します。',
              border: OutlineInputBorder(),
            ),
            items: availableAccessMethods
                .map(
                  (method) => DropdownMenuItem(
                    value: method,
                    child: Text(method.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onAccessMethodChanged(value);
              }
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          _AccessMethodDescription(method: resolvedAccessMethod),
          if (_isShowOrParade) ...[
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: ValueKey(
                '${facility.id}_'
                'performance_time_'
                '${preference.preferredPerformanceTime}',
              ),
              initialValue: preference.preferredPerformanceTime,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                labelText: '希望公演時刻',
                hintText: '例：17:35',
                helperText: '公式発表の公演時刻を入力してください。未定の場合は空欄にできます。',
                prefixIcon: Icon(Icons.schedule_outlined),
                border: OutlineInputBorder(),
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: _optionalTimeValidator,
              onChanged: onPreferredPerformanceTimeChanged,
            ),
          ],
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
                helperText: '予約時刻が登録されている場合は予約時刻を優先します。',
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
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: ValueKey(
                '${facility.id}_'
                'reservation_time_'
                '${preference.reservationTime}',
              ),
              initialValue: preference.reservationTime,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                labelText: '予約時刻',
                hintText: '例：12:30',
                helperText: '予約がない場合は空欄にしてください。',
                prefixIcon: Icon(Icons.event_available_outlined),
                border: OutlineInputBorder(),
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: _optionalTimeValidator,
              onChanged: onReservationTimeChanged,
            ),
          ],
          if (_usesEntryRequest) ...[
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<LotteryFallbackAction>(
              key: ValueKey(
                '${facility.id}_'
                'fallback_'
                '${preference.lotteryFallbackAction.name}',
              ),
              initialValue: preference.lotteryFallbackAction,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '抽選に外れた場合',
                helperText: 'エントリー受付に外れた場合の代替行動です。',
                border: OutlineInputBorder(),
              ),
              items: LotteryFallbackAction.values
                  .map(
                    (action) => DropdownMenuItem(
                      value: action,
                      child: Text(action.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onLotteryFallbackActionChanged(value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            _FallbackDescription(action: preference.lotteryFallbackAction),
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
              helperText: 'DPAやパス利用時でも、通常待機へ切り替える場合の判断材料として使用します。',
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
          if (facility.isCapsuleToy) ...[
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('カプセルトイを優先する'),
              subtitle: const Text('通常のショップより早い時間帯への配置を優先します。'),
              value: preference.prioritizeCapsuleToy,
              onChanged: onPrioritizeCapsuleToyChanged,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            key: ValueKey(
              '${facility.id}_'
              'memo_'
              '${preference.memo}',
            ),
            initialValue: preference.memo,
            decoration: const InputDecoration(
              labelText: 'メモ',
              hintText: '座席、鑑賞場所、同行者の希望など',
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

    return methods.toSet().toList(growable: false);
  }

  static String? _optionalTimeValidator(String? value) {
    final text = value?.trim().replaceAll('：', ':');

    if (text == null || text.isEmpty) {
      return null;
    }

    final match = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$').firstMatch(text);

    if (match == null) {
      return '時刻は「17:35」の形式で入力してください。';
    }

    return null;
  }
}

class _AccessMethodDescription extends StatelessWidget {
  const _AccessMethodDescription({required this.method});

  final FacilityAccessMethod method;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          _accessMethodIcon(method),
          size: 17,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            method.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _FallbackDescription extends StatelessWidget {
  const _FallbackDescription({required this.action});

  final LotteryFallbackAction action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.alt_route_outlined,
          size: 17,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            action.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

IconData _accessMethodIcon(FacilityAccessMethod method) {
  return switch (method) {
    FacilityAccessMethod.standby => Icons.groups_outlined,
    FacilityAccessMethod.dpa => Icons.bolt,
    FacilityAccessMethod.priorityPass => Icons.confirmation_number_outlined,
    FacilityAccessMethod.standbyPass => Icons.airplane_ticket_outlined,
    FacilityAccessMethod.entryRequest => Icons.how_to_reg_outlined,
    FacilityAccessMethod.reservation => Icons.event_available_outlined,
    FacilityAccessMethod.freeSeating => Icons.chair_alt_outlined,
  };
}
