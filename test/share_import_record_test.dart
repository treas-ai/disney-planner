import 'package:disney_planner/domain/entities/share_import_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('share import record can be serialized', () {
    final record = ShareImportRecord(
      importedAt: DateTime(2026, 8, 4, 15, 0),
      sourceLabel: 'LINE',
      kindLabel: '現在のプラン',
    );

    final restored = ShareImportRecord.fromJson(record.toJson());

    expect(restored.sourceLabel, 'LINE');
    expect(restored.kindLabel, '現在のプラン');
    expect(restored.importedAt, DateTime(2026, 8, 4, 15, 0));
  });
}
