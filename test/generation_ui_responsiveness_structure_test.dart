import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('生成は専用isolate entryで実行しUIクロージャを送らない', () {
    final source = File('lib/features/plan_review/schedule_controller.dart').readAsStringSync();
    expect(source, contains('Isolate.spawn<List<Object?>>'));
    expect(source, contains('_scheduleGenerationIsolateEntry'));
    expect(source, contains('_generateScheduleOffUi(request)'));
    expect(source, isNot(contains('Isolate.run(')));
    expect(source, isNot(contains('_scheduleEngine.generate(')));
    expect(RegExp(r'_generateScheduleOffUi\s*\(').allMatches(source).length, greaterThanOrEqualTo(3));
    expect(source, contains('final request = _ScheduleGenerationRequest('));
    expect(source, contains('<Object?>[receivePort.sendPort, request]'));
    expect(source, isNot(contains('_TodayPlanScreenState')));
    expect(source, isNot(contains('LiveController')));
  });

  test('生成中画面に処理段階を表示する', () {
    final source = File('lib/features/plan_review/plan_review_screen.dart').readAsStringSync();
    expect(source, contains('controller.generationStatus'));
  });
}
