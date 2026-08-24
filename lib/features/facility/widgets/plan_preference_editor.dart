import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../data/local/local_performance_schedule_repository.dart';
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
    this.vacationPackageEnabled = false,
    this.vacationPackageShowVoucherEnabled = false,
    this.vacationPackageRestaurantEnabled = false,
    this.visitDate,
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
  final bool vacationPackageEnabled;
  final bool vacationPackageShowVoucherEnabled;
  final bool vacationPackageRestaurantEnabled;
  final DateTime? visitDate;

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
          if (_isShowOrParade &&
              vacationPackageEnabled &&
              vacationPackageShowVoucherEnabled) ...[
            const SizedBox(height: AppSpacing.md),
            _VacationPackageShowTimeField(
              facility: facility,
              value: preference.preferredPerformanceTime,
              onChanged: onPreferredPerformanceTimeChanged,
              visitDate: visitDate,
            ),
          ],
          if (preference.accessMethod == FacilityAccessMethod.reservation) ...[
            const SizedBox(height: AppSpacing.md),
            _TenMinuteTimeField(
              key: ValueKey(
                '${facility.id}_reservation_${preference.reservationTime}',
              ),
              label: vacationPackageEnabled && vacationPackageRestaurantEnabled
                  ? '予約時刻（バケーションパッケージ対応）'
                  : '予約時刻',
              helperText: '予約・プライオリティ・シーティングの確定時刻を10分刻みで設定します。',
              value: preference.reservationTime,
              onChanged: onReservationTimeChanged,
            ),
          ],
          if (preference.accessMethod == FacilityAccessMethod.dpa ||
              preference.accessMethod ==
                  FacilityAccessMethod.priorityPass) ...[
            const SizedBox(height: AppSpacing.md),
            _TimeSettingField(
              key: ValueKey(
                '${facility.id}_scheduled_${preference.scheduledAccessTime}',
              ),
              label: preference.accessMethod == FacilityAccessMethod.dpa
                  ? 'DPA利用時刻'
                  : 'プライオリティパス利用時刻',
              helperText: '公式アプリで取得済みの利用時刻を設定します。',
              value: preference.scheduledAccessTime,
              onChanged: onScheduledAccessTimeChanged,
            ),
          ],
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


class _VacationPackageShowTimeField extends StatelessWidget {
  const _VacationPackageShowTimeField({
    required this.facility,
    required this.value,
    required this.onChanged,
    required this.visitDate,
  });

  final Facility facility;
  final String value;
  final ValueChanged<String> onChanged;
  final DateTime? visitDate;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: LocalPerformanceScheduleRepository().findOptions(
        parkId: facility.parkId,
        facilityId: facility.id,
        date: visitDate ?? DateTime.now(),
      ),
      builder: (context, snapshot) {
        final options = snapshot.data ?? const [];
        final registeredValues = options
            .map((option) => option.startTime)
            .toSet()
            .toList()
          ..sort();
        final usesRegisteredSchedule = registeredValues.isNotEmpty;
        final values = usesRegisteredSchedule
            ? <String>['', ...registeredValues]
            : _tenMinuteTimes();
        if (value.isNotEmpty && !values.contains(value)) {
          values.add(value);
          values.sort();
        }

        final dateLabel = visitDate == null
            ? '選択日'
            : '${visitDate!.month}/${visitDate!.day}';

        return DropdownButtonFormField<String>(
          key: ValueKey('${facility.id}_vp_show_$value'),
          initialValue: values.contains(value) ? value : '',
          decoration: InputDecoration(
            labelText: 'バケーションパッケージ・ショー鑑賞時刻',
            helperText: usesRegisteredSchedule
                ? '$dateLabelの登録済み公演時刻から、予約した回を選択します。'
                : '$dateLabelの公演時刻は未登録です。予約確認画面に記載された時刻を10分刻みで選択してください。',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.confirmation_number_outlined),
          ),
          items: values
              .map(
                (time) => DropdownMenuItem(
                  value: time,
                  child: Text(time.isEmpty ? '未設定' : time),
                ),
              )
              .toList(growable: false),
          onChanged: (selected) => onChanged(selected ?? ''),
        );
      },
    );
  }
}

List<String> _tenMinuteTimes() {
  final values = <String>[''];
  for (var hour = 6; hour <= 23; hour++) {
    for (var minute = 0; minute < 60; minute += 10) {
      values.add(
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      );
    }
  }
  return values;
}

class _TenMinuteTimeField extends StatelessWidget {
  const _TenMinuteTimeField({
    super.key,
    required this.label,
    required this.helperText,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String helperText;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final values = _tenMinuteTimes();
    if (value.isNotEmpty && !values.contains(value)) {
      values.add(value);
      values.sort();
    }

    return DropdownButtonFormField<String>(
      initialValue: values.contains(value) ? value : '',
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.schedule),
      ),
      items: values
          .map(
            (time) => DropdownMenuItem(
              value: time,
              child: Text(time.isEmpty ? '未設定' : time),
            ),
          )
          .toList(growable: false),
      onChanged: (selected) => onChanged(selected ?? ''),
    );
  }
}

class _TimeSettingField extends StatelessWidget {
  const _TimeSettingField({
    super.key,
    required this.label,
    required this.helperText,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String helperText;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey(value),
      initialValue: value,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        hintText: '時刻を選択',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.schedule),
        suffixIcon: value.isEmpty
            ? const Icon(Icons.arrow_drop_down)
            : IconButton(
                tooltip: '時刻を解除',
                onPressed: () => onChanged(''),
                icon: const Icon(Icons.clear),
              ),
      ),
      onTap: () => _selectTime(context),
    );
  }

  Future<void> _selectTime(BuildContext context) async {
    final initialTime = _parseTime(value) ?? const TimeOfDay(hour: 12, minute: 0);
    final selected = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: label,
      cancelText: 'キャンセル',
      confirmText: '設定',
    );

    if (selected == null || !context.mounted) {
      return;
    }

    final hour = selected.hour.toString().padLeft(2, '0');
    final minute = selected.minute.toString().padLeft(2, '0');
    onChanged('$hour:$minute');
  }

  TimeOfDay? _parseTime(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
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
    LotteryFallbackAction.dpaIfAvailable => 'DPAを検討',
    LotteryFallbackAction.skip => 'この施設を諦める',
  };
}
