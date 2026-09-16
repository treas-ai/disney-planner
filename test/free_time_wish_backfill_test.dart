import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('未採用希望を自由時間化より先に再探索する', () {
    final source = File('lib/domain/services/schedule_engine.dart').readAsStringSync();
    final backfillCall = source.indexOf('_backfillUnscheduledWishFacilities(');
    final flexCall = source.indexOf('_addFlexibleOpenTimeBlocks(', backfillCall);
    expect(backfillCall, greaterThanOrEqualTo(0));
    expect(flexCall, greaterThan(backfillCall));
    expect(source, contains("id: 'backfill_\${facility.id}'"));
    expect(source, contains('未採用の希望をDPA追加判定より先に組み込みました'));
  });
}
