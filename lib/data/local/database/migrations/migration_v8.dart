import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MigrationV8 {
  const MigrationV8._();

  static Future<void> migrate(Database database) async {
    final columns = await database.rawQuery('PRAGMA table_info(facilities)');

    final existingColumnNames = columns
        .map((column) => column['name'])
        .whereType<String>()
        .toSet();

    if (!existingColumnNames.contains('operating_status')) {
      await database.execute('''
        ALTER TABLE facilities
        ADD COLUMN operating_status
        TEXT NOT NULL DEFAULT 'operating'
        ''');
    }

    if (!existingColumnNames.contains('closure_start_date')) {
      await database.execute('''
        ALTER TABLE facilities
        ADD COLUMN closure_start_date TEXT
        ''');
    }

    if (!existingColumnNames.contains('closure_end_date')) {
      await database.execute('''
        ALTER TABLE facilities
        ADD COLUMN closure_end_date TEXT
        ''');
    }

    if (!existingColumnNames.contains('operating_status_note')) {
      await database.execute('''
        ALTER TABLE facilities
        ADD COLUMN operating_status_note TEXT
        ''');
    }

    if (!existingColumnNames.contains('operating_status_checked_at')) {
      await database.execute('''
        ALTER TABLE facilities
        ADD COLUMN operating_status_checked_at TEXT
        ''');
    }

    await database.execute('''
      UPDATE facilities
      SET operating_status = 'temporarilyClosed'
      WHERE (
        is_operating = 0
        OR status != 'open'
      )
      AND operating_status = 'operating'
      ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS
      index_facilities_operating_status
      ON facilities (
        park_id,
        operating_status
      )
      ''');
  }
}
