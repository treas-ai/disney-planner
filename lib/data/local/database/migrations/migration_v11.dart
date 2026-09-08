import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MigrationV11 {
  const MigrationV11._();

  static Future<void> migrate(Database database) async {
    final columns = await database.rawQuery('PRAGMA table_info(facilities)');
    final existing = columns.map((column) => column['name']).whereType<String>().toSet();

    if (!existing.contains('available_start_date')) {
      await database.execute('ALTER TABLE facilities ADD COLUMN available_start_date TEXT');
    }
    if (!existing.contains('available_end_date')) {
      await database.execute('ALTER TABLE facilities ADD COLUMN available_end_date TEXT');
    }
  }
}
