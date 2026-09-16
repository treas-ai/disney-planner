import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('当日取得候補は来園日の施設運営可否を通す', () {
    final source = File(
      'lib/features/today/today_access_input_screen.dart',
    ).readAsStringSync();

    expect(source, contains('facility.canAddToPlanAt(visitDate)'));
    expect(source, contains('supportsMobileOrder && facility.canAddToPlanAt(visitDate)'));
  });

  test('ショーとパレードは来園日の公式公演データがある施設だけを表示する', () {
    final source = File(
      'lib/features/today/today_access_input_screen.dart',
    ).readAsStringSync();

    expect(source, contains('findParkOptions(parkId: parkId, date: visitDate)'));
    expect(source, contains('_scheduledEntertainmentIds.contains(facility.id)'));
  });
}
