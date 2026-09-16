import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('today input is limited to DPA, show lottery, and mobile order', () {
    final source = File(
      'lib/features/today/today_access_input_screen.dart',
    ).readAsStringSync();

    expect(source, contains('facility.supportsDpa'));
    expect(source, contains('facility.supportsMobileOrder'));
    expect(source, contains('facility.requiresEntryRequest'));
    expect(source, contains('facility.category == FacilityCategory.show'));
    expect(source, isNot(contains('facility.supportsStandbyPass')));
  });
}
