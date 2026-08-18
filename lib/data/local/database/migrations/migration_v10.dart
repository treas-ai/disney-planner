import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MigrationV10 {
  const MigrationV10._();

  static Future<void> migrate(Database database) async {
    final columns = await database.rawQuery('PRAGMA table_info(facilities)');
    final existing = columns
        .map((column) => column['name'])
        .whereType<String>()
        .toSet();

    if (!existing.contains('operating_schedules_json')) {
      await database.execute(
        'ALTER TABLE facilities ADD COLUMN operating_schedules_json TEXT',
      );
    }
  }
}
