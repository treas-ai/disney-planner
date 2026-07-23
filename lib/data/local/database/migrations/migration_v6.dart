import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MigrationV6 {
  const MigrationV6._();

  static Future<void> migrate(Database database) async {
    final columns = await database.rawQuery('PRAGMA table_info(facilities)');

    final existingColumnNames = columns
        .map((column) => column['name'])
        .whereType<String>()
        .toSet();

    await _addTextColumn(
      database: database,
      existingColumnNames: existingColumnNames,
      columnName: 'representative_menu',
    );

    await _addTextColumn(
      database: database,
      existingColumnNames: existingColumnNames,
      columnName: 'popcorn_flavor',
    );

    await _addTextColumn(
      database: database,
      existingColumnNames: existingColumnNames,
      columnName: 'menu_note',
    );

    await _addIntegerColumn(
      database: database,
      existingColumnNames: existingColumnNames,
      columnName: 'is_show_restaurant',
      defaultValue: 0,
    );

    await _addTextColumn(
      database: database,
      existingColumnNames: existingColumnNames,
      columnName: 'show_name',
    );

    await database.execute('''
      CREATE INDEX IF NOT EXISTS
      index_facilities_show_restaurant
      ON facilities (
        park_id,
        is_show_restaurant
      )
      ''');
  }

  static Future<void> _addTextColumn({
    required Database database,
    required Set<String> existingColumnNames,
    required String columnName,
  }) async {
    if (existingColumnNames.contains(columnName)) {
      return;
    }

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN $columnName TEXT
      ''');

    existingColumnNames.add(columnName);
  }

  static Future<void> _addIntegerColumn({
    required Database database,
    required Set<String> existingColumnNames,
    required String columnName,
    required int defaultValue,
  }) async {
    if (existingColumnNames.contains(columnName)) {
      return;
    }

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN $columnName
      INTEGER NOT NULL DEFAULT $defaultValue
      ''');

    existingColumnNames.add(columnName);
  }
}
