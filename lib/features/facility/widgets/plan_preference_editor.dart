import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/facility.dart';
import '../../../domain/entities/plan_preference.dart';
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
    required this.onUseDpaChanged,
    required this.onUsePriorityPassChanged,
    required this.onMemoChanged,
  });

  final Facility facility;
  final PlanPreference preference;

  final ValueChanged<PriorityLevel> onPriorityChanged;
  final ValueChanged<PreferredTime> onPreferredTimeChanged;
  final ValueChanged<WaitTolerance> onWaitToleranceChanged;
  final ValueChanged<bool> onUseDpaChanged;
  final ValueChanged<bool> onUsePriorityPassChanged;
  final ValueChanged<String> onMemoChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(facility.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<PriorityLevel>(
            initialValue: preference.priority,
            decoration: const InputDecoration(
              labelText: '優先度',
              border: OutlineInputBorder(),
            ),
            items: PriorityLevel.values
                .map(
                  (priority) => DropdownMenuItem(
                    value: priority,
                    child: Text('${priority.label} ${priority.stars}'),
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
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<WaitTolerance>(
            initialValue: preference.waitTolerance,
            decoration: const InputDecoration(
              labelText: '待ち時間許容',
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
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            title: const Text('DPAを使う'),
            value: preference.useDpa,
            onChanged: onUseDpaChanged,
          ),
          SwitchListTile(
            title: const Text('Priority Passを使う'),
            value: preference.usePriorityPass,
            onChanged: onUsePriorityPassChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
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
