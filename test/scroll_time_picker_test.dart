import 'package:disney_planner/core/widgets/scroll_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('9:00から21:00を10分刻みで生成する', () {
    final values = buildScrollTimeOptions(
      minTime: const TimeOfDay(hour: 9, minute: 0),
      maxTime: const TimeOfDay(hour: 21, minute: 0),
      minuteStep: 10,
    );

    expect(values.first, const TimeOfDay(hour: 9, minute: 0));
    expect(values[1], const TimeOfDay(hour: 9, minute: 10));
    expect(values.last, const TimeOfDay(hour: 21, minute: 0));
    expect(values.length, 73);
  });

  test('朝の並び開始用に5分刻みも生成できる', () {
    final values = buildScrollTimeOptions(
      minTime: const TimeOfDay(hour: 4, minute: 0),
      maxTime: const TimeOfDay(hour: 10, minute: 0),
      minuteStep: 5,
    );

    expect(values.first, const TimeOfDay(hour: 4, minute: 0));
    expect(values[1], const TimeOfDay(hour: 4, minute: 5));
    expect(values.last, const TimeOfDay(hour: 10, minute: 0));
  });
}
