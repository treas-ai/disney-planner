import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('朝一と通常配置で待ち時間機会損失の探索範囲を分ける', () {
    final source = File('lib/domain/services/schedule_engine.dart').readAsStringSync();

    expect(source, contains('bool openingOpportunity = false'));
    expect(source, contains('openingOpportunity: true'));
    expect(source, contains('openingLookAheadReliableBands = 2'));
    expect(source, contains('futureCandidates.length >= openingLookAheadReliableBands'));
    expect(source, contains('? candidate.waitMinutes > representativeFuture.waitMinutes'));
    expect(source, contains(': candidate.waitMinutes < representativeFuture.waitMinutes'));
  });
}
