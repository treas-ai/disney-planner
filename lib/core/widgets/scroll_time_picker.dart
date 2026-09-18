import 'package:flutter/material.dart';

/// Disney Planner共通の2ホイール式時刻選択。
///
/// 「時」と「分」を独立してスクロールし、用途ごとの範囲・刻み幅だけを
/// 表示します。内部の時刻制約は呼び出し側の[minTime]/[maxTime]を維持します。
Future<TimeOfDay?> showScrollTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  required TimeOfDay minTime,
  required TimeOfDay maxTime,
  int minuteStep = 10,
  String title = '時刻を選択',
  String? helperText,
}) {
  assert(minuteStep > 0 && minuteStep <= 60);

  final options = buildScrollTimeOptions(
    minTime: minTime,
    maxTime: maxTime,
    minuteStep: minuteStep,
  );
  if (options.isEmpty) return Future.value(null);

  final initialMinutes = initialTime.hour * 60 + initialTime.minute;
  var initial = options.first;
  var bestDistance = 1 << 30;
  for (final option in options) {
    final minutes = option.hour * 60 + option.minute;
    final distance = (minutes - initialMinutes).abs();
    if (distance < bestDistance) {
      bestDistance = distance;
      initial = option;
    }
  }

  return showDialog<TimeOfDay>(
    context: context,
    builder: (dialogContext) {
      var selectedHour = initial.hour;
      var selectedMinute = initial.minute;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          final hours = buildScrollHourOptions(
            minTime: minTime,
            maxTime: maxTime,
          );
          final minutes = buildScrollMinuteOptionsForHour(
            hour: selectedHour,
            minTime: minTime,
            maxTime: maxTime,
            minuteStep: minuteStep,
          );
          if (!minutes.contains(selectedMinute)) {
            selectedMinute = minutes.first;
          }

          final hourIndex = hours.indexOf(selectedHour);
          final minuteIndex = minutes.indexOf(selectedMinute);

          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (helperText != null) ...[
                    Text(
                      helperText,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: _TimeWheel(
                          key: ValueKey('hour-$hourIndex'),
                          label: '時',
                          values: hours,
                          selectedIndex: hourIndex,
                          formatter: (value) =>
                              value.toString().padLeft(2, '0'),
                          onChanged: (index) {
                            final nextHour = hours[index];
                            final nextMinutes = buildScrollMinuteOptionsForHour(
                              hour: nextHour,
                              minTime: minTime,
                              maxTime: maxTime,
                              minuteStep: minuteStep,
                            );
                            setDialogState(() {
                              selectedHour = nextHour;
                              if (!nextMinutes.contains(selectedMinute)) {
                                selectedMinute = nextMinutes.first;
                              }
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 30),
                        child: Text(
                          ':',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      Expanded(
                        child: _TimeWheel(
                          key: ValueKey('minute-$selectedHour-$minuteIndex'),
                          label: '分',
                          values: minutes,
                          selectedIndex: minuteIndex,
                          formatter: (value) =>
                              value.toString().padLeft(2, '0'),
                          onChanged: (index) {
                            setDialogState(() {
                              selectedMinute = minutes[index];
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${selectedHour.toString().padLeft(2, '0')}:'
                    '${selectedMinute.toString().padLeft(2, '0')}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatTimeOfDay(minTime)}〜${formatTimeOfDay(maxTime)}・$minuteStep分刻み',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(
                  TimeOfDay(hour: selectedHour, minute: selectedMinute),
                ),
                child: const Text('この時刻にする'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _TimeWheel extends StatelessWidget {
  const _TimeWheel({
    super.key,
    required this.label,
    required this.values,
    required this.selectedIndex,
    required this.formatter,
    required this.onChanged,
  });

  final String label;
  final List<int> values;
  final int selectedIndex;
  final String Function(int value) formatter;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Container(
          height: 190,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              ListWheelScrollView.useDelegate(
                controller: FixedExtentScrollController(
                  initialItem: selectedIndex < 0 ? 0 : selectedIndex,
                ),
                itemExtent: 48,
                diameterRatio: 1.7,
                perspective: 0.002,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: onChanged,
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: values.length,
                  builder: (context, index) => Center(
                    child: Text(
                      formatter(values[index]),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

List<int> buildScrollHourOptions({
  required TimeOfDay minTime,
  required TimeOfDay maxTime,
}) {
  final minMinutes = minTime.hour * 60 + minTime.minute;
  final maxMinutes = maxTime.hour * 60 + maxTime.minute;
  if (maxMinutes < minMinutes) return const [];
  return [for (var hour = minTime.hour; hour <= maxTime.hour; hour++) hour];
}

List<int> buildScrollMinuteOptionsForHour({
  required int hour,
  required TimeOfDay minTime,
  required TimeOfDay maxTime,
  int minuteStep = 10,
}) {
  assert(minuteStep > 0 && minuteStep <= 60);
  final options = buildScrollTimeOptions(
    minTime: minTime,
    maxTime: maxTime,
    minuteStep: minuteStep,
  );
  return options
      .where((value) => value.hour == hour)
      .map((value) => value.minute)
      .toSet()
      .toList()
    ..sort();
}

List<TimeOfDay> buildScrollTimeOptions({
  required TimeOfDay minTime,
  required TimeOfDay maxTime,
  int minuteStep = 10,
}) {
  assert(minuteStep > 0 && minuteStep <= 60);
  final minMinutes = minTime.hour * 60 + minTime.minute;
  final maxMinutes = maxTime.hour * 60 + maxTime.minute;
  if (maxMinutes < minMinutes) return const [];

  final result = <TimeOfDay>[];
  for (var minutes = minMinutes; minutes <= maxMinutes; minutes += minuteStep) {
    result.add(
      TimeOfDay(
        hour: minutes ~/ 60,
        minute: minutes % 60,
      ),
    );
  }
  if (result.isEmpty ||
      result.last.hour != maxTime.hour ||
      result.last.minute != maxTime.minute) {
    result.add(maxTime);
  }
  return result;
}

String formatTimeOfDay(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
