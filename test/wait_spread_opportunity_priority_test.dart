import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('待ち時間テーブルの差と現在の安値機会を通常配置の優先順位に使う', () {
    final source = File('lib/domain/services/schedule_engine.dart').readAsStringSync();
    expect(source, contains('_waitProfileSpreadOpportunity'));
    expect(source, contains('spreadMinutes: maxWait - minWait'));
    expect(source, contains('maxWait - currentWait'));
    expect(source, contains('cheapWindowCaptureMinutes.compareTo'));
    expect(source, contains('waitSpreadMinutes.compareTo'));
    expect(source, contains('_isReliableTimingRange'));
  });
}
