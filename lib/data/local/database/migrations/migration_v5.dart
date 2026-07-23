import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MigrationV5 {
  const MigrationV5._();

  static Future<void> migrate(Database database) async {
    final columns = await database.rawQuery('''
      PRAGMA table_info(facilities)
      ''');

    final existingColumnNames = columns
        .map((column) => column['name'])
        .whereType<String>()
        .toSet();

    if (!existingColumnNames.contains('restaurant_type')) {
      await database.execute('''
        ALTER TABLE facilities
        ADD COLUMN restaurant_type
        TEXT NOT NULL DEFAULT 'none'
        ''');
    }

    await database.execute('''
      CREATE INDEX IF NOT EXISTS
      index_facilities_restaurant_type
      ON facilities (
        park_id,
        restaurant_type
      )
      ''');

    await _updateExistingRestaurantTypes(database);
  }

  static Future<void> _updateExistingRestaurantTypes(Database database) async {
    await database.execute('''
      UPDATE facilities
      SET restaurant_type = 'tableService'
      WHERE category = 'restaurant'
        AND is_table_service = 1
        AND restaurant_type = 'none'
      ''');

    await database.execute('''
      UPDATE facilities
      SET restaurant_type = 'foodWagon'
      WHERE category = 'restaurant'
        AND restaurant_type = 'none'
        AND (
          name LIKE '%ワゴン%'
          OR name LIKE '%ポップコーン%'
        )
      ''');

    await database.execute('''
      UPDATE facilities
      SET restaurant_type = 'bakeryCafe'
      WHERE category = 'restaurant'
        AND restaurant_type = 'none'
        AND (
          name LIKE '%カフェ%'
          OR name LIKE '%ベーカリー%'
        )
      ''');

    await database.execute('''
      UPDATE facilities
      SET restaurant_type = 'counterService'
      WHERE category = 'restaurant'
        AND restaurant_type = 'none'
      ''');

    await database.execute('''
      UPDATE facilities
      SET restaurant_type = 'none'
      WHERE category != 'restaurant'
        AND restaurant_type != 'none'
      ''');
  }
}
