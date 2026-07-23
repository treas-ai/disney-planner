import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MigrationV2 {
  const MigrationV2._();

  static Future<void> migrate(Database database) async {
    await database.transaction((transaction) async {
      await _addParkColumns(transaction);
      await _addAreaColumns(transaction);
      await _addFacilityColumns(transaction);
      await _updateExistingMasterData(transaction);
      await _createIndexes(transaction);
    });
  }

  static Future<void> _addParkColumns(DatabaseExecutor database) async {
    await database.execute('''
      ALTER TABLE parks
      ADD COLUMN country TEXT NOT NULL DEFAULT 'Japan'
      ''');

    await database.execute('''
      ALTER TABLE parks
      ADD COLUMN timezone TEXT NOT NULL DEFAULT 'Asia/Tokyo'
      ''');
  }

  static Future<void> _addAreaColumns(DatabaseExecutor database) async {
    await database.execute('''
      ALTER TABLE areas
      ADD COLUMN display_order INTEGER NOT NULL DEFAULT 0
      ''');
  }

  static Future<void> _addFacilityColumns(DatabaseExecutor database) async {
    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN duration_minutes INTEGER NOT NULL DEFAULT 60
      ''');

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN is_indoor INTEGER NOT NULL DEFAULT 0
      ''');

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN supports_dpa INTEGER NOT NULL DEFAULT 0
      ''');

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN supports_priority_pass INTEGER NOT NULL DEFAULT 0
      ''');

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN supports_single_rider INTEGER NOT NULL DEFAULT 0
      ''');

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN requires_entry_request INTEGER NOT NULL DEFAULT 0
      ''');

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN requires_reservation INTEGER NOT NULL DEFAULT 0
      ''');

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN is_seasonal INTEGER NOT NULL DEFAULT 0
      ''');

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN is_operating INTEGER NOT NULL DEFAULT 1
      ''');

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN min_height REAL
      ''');

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN target_age TEXT
      ''');

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN display_order INTEGER NOT NULL DEFAULT 0
      ''');

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN ride_type TEXT
      ''');

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN thrill_level INTEGER
      ''');

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN is_water_ride INTEGER NOT NULL DEFAULT 0
      ''');

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN is_dark_ride INTEGER NOT NULL DEFAULT 0
      ''');

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN is_table_service INTEGER NOT NULL DEFAULT 0
      ''');

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN supports_mobile_order INTEGER NOT NULL DEFAULT 0
      ''');

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN supports_priority_seating INTEGER NOT NULL DEFAULT 0
      ''');

    await database.execute('''
      ALTER TABLE facilities
      ADD COLUMN reservation_required INTEGER NOT NULL DEFAULT 0
      ''');
  }

  static Future<void> _updateExistingMasterData(
    DatabaseExecutor database,
  ) async {
    await database.update(
      'areas',
      {'display_order': 1},
      where: 'id = ?',
      whereArgs: ['tdl_world_bazaar'],
    );

    await database.update(
      'areas',
      {'display_order': 2},
      where: 'id = ?',
      whereArgs: ['tdl_adventureland'],
    );

    await database.update(
      'areas',
      {'display_order': 3},
      where: 'id = ?',
      whereArgs: ['tdl_westernland'],
    );

    await database.update(
      'areas',
      {'display_order': 4},
      where: 'id = ?',
      whereArgs: ['tdl_fantasyland'],
    );

    await database.update(
      'areas',
      {'display_order': 5},
      where: 'id = ?',
      whereArgs: ['tdl_tomorrowland'],
    );

    await database.update(
      'areas',
      {'display_order': 1},
      where: 'id = ?',
      whereArgs: ['tds_mediterranean_harbor'],
    );

    await database.update(
      'areas',
      {'display_order': 2},
      where: 'id = ?',
      whereArgs: ['tds_american_waterfront'],
    );

    await database.update(
      'areas',
      {'display_order': 3},
      where: 'id = ?',
      whereArgs: ['tds_port_discovery'],
    );

    await database.update(
      'areas',
      {'display_order': 4},
      where: 'id = ?',
      whereArgs: ['tds_lost_river_delta'],
    );

    await database.update(
      'areas',
      {'display_order': 5},
      where: 'id = ?',
      whereArgs: ['tds_arabian_coast'],
    );

    await database.update(
      'areas',
      {'display_order': 6},
      where: 'id = ?',
      whereArgs: ['tds_mermaid_lagoon'],
    );

    await database.update(
      'areas',
      {'display_order': 7},
      where: 'id = ?',
      whereArgs: ['tds_mysterious_island'],
    );

    await database.update(
      'areas',
      {'display_order': 8},
      where: 'id = ?',
      whereArgs: ['tds_fantasy_springs'],
    );

    await database.update(
      'facilities',
      {
        'duration_minutes': 8,
        'is_indoor': 1,
        'supports_dpa': 1,
        'display_order': 1,
        'ride_type': 'tracklessDarkRide',
        'thrill_level': 2,
        'is_dark_ride': 1,
      },
      where: 'id = ?',
      whereArgs: ['tdl_beauty_and_the_beast'],
    );

    await database.update(
      'facilities',
      {'duration_minutes': 30, 'is_indoor': 1, 'display_order': 1},
      where: 'id = ?',
      whereArgs: ['tdl_grand_emporium'],
    );

    await database.update(
      'facilities',
      {
        'duration_minutes': 5,
        'is_indoor': 1,
        'supports_dpa': 1,
        'display_order': 1,
        'ride_type': 'flightSimulator',
        'thrill_level': 2,
      },
      where: 'id = ?',
      whereArgs: ['tds_soaring'],
    );

    await database.update(
      'facilities',
      {
        'duration_minutes': 25,
        'is_indoor': 1,
        'requires_entry_request': 1,
        'display_order': 1,
      },
      where: 'id = ?',
      whereArgs: ['tds_big_band_beat'],
    );

    await database.update(
      'facilities',
      {
        'duration_minutes': 90,
        'is_indoor': 1,
        'requires_reservation': 0,
        'is_table_service': 1,
        'supports_priority_seating': 1,
        'display_order': 2,
      },
      where: 'id = ?',
      whereArgs: ['tds_magellans'],
    );
  }

  static Future<void> _createIndexes(DatabaseExecutor database) async {
    await database.execute('''
      CREATE INDEX IF NOT EXISTS index_areas_display_order
      ON areas (park_id, display_order)
      ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS index_facilities_display_order
      ON facilities (park_id, area_id, display_order)
      ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS index_facilities_operating
      ON facilities (park_id, is_operating)
      ''');
  }
}
