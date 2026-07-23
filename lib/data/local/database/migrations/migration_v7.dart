import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MigrationV7 {
  const MigrationV7._();

  static Future<void> migrate(Database database) async {
    final columns = await database.rawQuery('PRAGMA table_info(facilities)');

    final existingColumnNames = columns
        .map((column) => column['name'])
        .whereType<String>()
        .toSet();

    if (!existingColumnNames.contains('official_url')) {
      await database.execute('''
        ALTER TABLE facilities
        ADD COLUMN official_url TEXT
        ''');
    }

    if (!existingColumnNames.contains('menu_url')) {
      await database.execute('''
        ALTER TABLE facilities
        ADD COLUMN menu_url TEXT
        ''');
    }
  }
}
