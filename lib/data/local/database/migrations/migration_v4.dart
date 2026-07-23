import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MigrationV4 {
  const MigrationV4._();

  static Future<void> migrate(Database database) async {
    await database.transaction((transaction) async {
      await transaction.execute('''
          ALTER TABLE facilities
          ADD COLUMN shop_type TEXT NOT NULL DEFAULT 'none'
          ''');

      await transaction.execute('''
          ALTER TABLE facilities
          ADD COLUMN supports_standby_pass
          INTEGER NOT NULL DEFAULT 0
          ''');

      await transaction.execute('''
          CREATE INDEX IF NOT EXISTS
          index_facilities_shop_type
          ON facilities (
            park_id,
            shop_type
          )
          ''');

      await transaction.execute('''
          CREATE INDEX IF NOT EXISTS
          index_facilities_standby_pass
          ON facilities (
            park_id,
            supports_standby_pass
          )
          ''');
    });
  }
}
