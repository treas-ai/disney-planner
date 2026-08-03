import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MigrationV9 {
  const MigrationV9._();

  static Future<void> migrate(Database database) async {
    final columns = await database.rawQuery('PRAGMA table_info(facilities)');
    final existing = columns
        .map((column) => column['name'])
        .whereType<String>()
        .toSet();

    Future<void> addColumn(String name, String definition) async {
      if (existing.contains(name)) {
        return;
      }

      await database.execute(
        'ALTER TABLE facilities ADD COLUMN $name $definition',
      );
    }

    await addColumn('dining_location_type', "TEXT NOT NULL DEFAULT 'inPark'");
    await addColumn('meal_periods', 'TEXT');
    await addColumn('requires_park_exit', 'INTEGER NOT NULL DEFAULT 0');
    await addColumn('requires_hotel_stay', 'INTEGER NOT NULL DEFAULT 0');
    await addColumn('hotel_id', 'TEXT');
    await addColumn('outbound_travel_minutes', 'INTEGER NOT NULL DEFAULT 0');
    await addColumn('return_travel_minutes', 'INTEGER NOT NULL DEFAULT 0');
  }
}
