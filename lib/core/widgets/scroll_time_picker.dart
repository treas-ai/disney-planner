import 'package:flutter/material.dart';

/// Disney Planner共通のスクロール式時刻選択。
///
/// 時計盤UIを使わず、用途ごとの範囲・刻み幅だけを表示します。
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
  var selectedIndex = 0;
  var bestDistance = 1 << 30;
  for (var i = 0; i < options.length; i++) {
    final minutes = options[i].hour * 60 + options[i].minute;
    final distance = (minutes - initialMinutes).abs();
    if (distance < bestDistance) {
      bestDistance = distance;
      selectedIndex = i;
    }
  }

  return showDialog<TimeOfDay>(
    context: context,
    builder: (dialogContext) {
      final controller = FixedExtentScrollController(
        initialItem: selectedIndex,
      );
      var currentIndex = selectedIndex;

      return StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 320,
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
                Container(
                  height: 230,
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
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      ListWheelScrollView.useDelegate(
                        controller: controller,
                        itemExtent: 48,
                        diameterRatio: 1.7,
                        perspective: 0.002,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          setDialogState(() => currentIndex = index);
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: options.length,
                          builder: (context, index) {
                            final value = options[index];
                            final selected = index == currentIndex;
                            return Center(
                              child: Text(
                                formatTimeOfDay(value),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w400,
                                      color: selected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer
                                          : null,
                                    ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
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
                options[currentIndex],
              ),
              child: const Text('この時刻にする'),
            ),
          ],
        ),
      );
    },
  );
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
