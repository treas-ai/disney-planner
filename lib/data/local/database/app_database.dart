import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../master_data/master_data_loader.dart';
import 'migrations/migration_v2.dart';
import 'migrations/migration_v3.dart';
import 'migrations/migration_v4.dart';
import 'migrations/migration_v5.dart';
import 'migrations/migration_v6.dart';
import 'migrations/migration_v7.dart';

class AppDatabase {
  AppDatabase._();

  static const String databaseName = 'disney_planner.db';

  static const int databaseVersion = 7;

  static Database? _database;

  static bool _databaseFactoryInitialized = false;

  static Future<Database> get instance async {
    final existingDatabase = _database;

    if (existingDatabase != null && existingDatabase.isOpen) {
      return existingDatabase;
    }

    _initializeDatabaseFactory();

    final databaseDirectory = await getDatabasesPath();

    final databasePath = path.join(databaseDirectory, databaseName);

    _database = await openDatabase(
      databasePath,
      version: databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );

    return _database!;
  }

  static void _initializeDatabaseFactory() {
    if (_databaseFactoryInitialized) {
      return;
    }

    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _databaseFactoryInitialized = true;
  }

  static Future<void> _onConfigure(Database database) async {
    await database.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database database, int version) async {
    await database.transaction((transaction) async {
      await _createTables(transaction);

      await _insertResort(transaction);

      const loader = MasterDataLoader();

      await loader.importAll(transaction);
    });
  }

  static Future<void> _onUpgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await MigrationV2.migrate(database);
    }

    if (oldVersion < 3) {
      await MigrationV3.migrate(database);
    }

    if (oldVersion < 4) {
      await MigrationV4.migrate(database);
    }

    if (oldVersion < 5) {
      await MigrationV5.migrate(database);
    }

    if (oldVersion < 6) {
      await MigrationV6.migrate(database);
    }

    if (oldVersion < 7) {
      await MigrationV7.migrate(database);
    }
  }

  static Future<void> _onOpen(Database database) async {
    try {
      const loader = MasterDataLoader();

      await database.transaction((transaction) async {
        await loader.importAll(transaction);
      });

      final totalRows = await database.rawQuery('''
        SELECT COUNT(*) AS count
        FROM facilities
        ''');

      final linkRows = await database.rawQuery('''
        SELECT COUNT(*) AS count
        FROM facilities
        WHERE official_url IS NOT NULL
           OR menu_url IS NOT NULL
        ''');

      final totalCount = totalRows.first['count'] as int? ?? 0;

      final linkCount = linkRows.first['count'] as int? ?? 0;

      debugPrint(
        'マスターデータ同期完了：'
        '全施設$totalCount件、'
        '公式リンク設定済み$linkCount件',
      );
    } catch (error, stackTrace) {
      debugPrint('マスターデータ同期に失敗しました: $error');

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  static Future<void> _createTables(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE resorts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        country TEXT NOT NULL
      )
      ''');

    await database.execute('''
      CREATE TABLE parks (
        id TEXT PRIMARY KEY,
        resort_id TEXT NOT NULL,
        name TEXT NOT NULL,
        open_hour INTEGER NOT NULL,
        open_minute INTEGER NOT NULL,
        close_hour INTEGER NOT NULL,
        close_minute INTEGER NOT NULL,
        status TEXT NOT NULL,
        country TEXT NOT NULL DEFAULT 'Japan',
        timezone TEXT NOT NULL DEFAULT 'Asia/Tokyo',

        FOREIGN KEY (resort_id)
          REFERENCES resorts (id)
          ON DELETE CASCADE
      )
      ''');

    await database.execute('''
      CREATE TABLE areas (
        id TEXT PRIMARY KEY,
        park_id TEXT NOT NULL,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        display_order INTEGER NOT NULL DEFAULT 0,

        FOREIGN KEY (park_id)
          REFERENCES parks (id)
          ON DELETE CASCADE
      )
      ''');

    await database.execute('''
      CREATE TABLE facilities (
        id TEXT PRIMARY KEY,
        park_id TEXT NOT NULL,
        area_id TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT NOT NULL,

        latitude REAL NOT NULL,
        longitude REAL NOT NULL,

        open_hour INTEGER,
        open_minute INTEGER,
        close_hour INTEGER,
        close_minute INTEGER,

        priority TEXT NOT NULL,
        status TEXT NOT NULL,
        description TEXT,

        reservation_type TEXT,
        reservation_time TEXT,

        wait_minutes INTEGER,
        wait_updated_at TEXT,

        duration_minutes INTEGER
          NOT NULL DEFAULT 60,

        is_indoor INTEGER
          NOT NULL DEFAULT 0,

        supports_dpa INTEGER
          NOT NULL DEFAULT 0,

        supports_priority_pass INTEGER
          NOT NULL DEFAULT 0,

        supports_standby_pass INTEGER
          NOT NULL DEFAULT 0,

        supports_single_rider INTEGER
          NOT NULL DEFAULT 0,

        requires_entry_request INTEGER
          NOT NULL DEFAULT 0,

        requires_reservation INTEGER
          NOT NULL DEFAULT 0,

        is_seasonal INTEGER
          NOT NULL DEFAULT 0,

        is_operating INTEGER
          NOT NULL DEFAULT 1,

        min_height REAL,
        target_age TEXT,

        display_order INTEGER
          NOT NULL DEFAULT 0,

        ride_type TEXT,
        thrill_level INTEGER,

        is_water_ride INTEGER
          NOT NULL DEFAULT 0,

        is_dark_ride INTEGER
          NOT NULL DEFAULT 0,

        is_table_service INTEGER
          NOT NULL DEFAULT 0,

        supports_mobile_order INTEGER
          NOT NULL DEFAULT 0,

        supports_priority_seating INTEGER
          NOT NULL DEFAULT 0,

        reservation_required INTEGER
          NOT NULL DEFAULT 0,

        shop_type TEXT
          NOT NULL DEFAULT 'none',

        restaurant_type TEXT
          NOT NULL DEFAULT 'none',

        representative_menu TEXT,
        popcorn_flavor TEXT,
        menu_note TEXT,

        is_show_restaurant INTEGER
          NOT NULL DEFAULT 0,

        show_name TEXT,

        official_url TEXT,
        menu_url TEXT,

        FOREIGN KEY (park_id)
          REFERENCES parks (id)
          ON DELETE CASCADE,

        FOREIGN KEY (area_id)
          REFERENCES areas (id)
          ON DELETE CASCADE
      )
      ''');

    await database.execute('''
      CREATE INDEX index_parks_resort_id
      ON parks (resort_id)
      ''');

    await database.execute('''
      CREATE INDEX index_areas_park_id
      ON areas (park_id)
      ''');

    await database.execute('''
      CREATE INDEX index_areas_display_order
      ON areas (
        park_id,
        display_order
      )
      ''');

    await database.execute('''
      CREATE INDEX index_facilities_park_id
      ON facilities (park_id)
      ''');

    await database.execute('''
      CREATE INDEX index_facilities_area_id
      ON facilities (area_id)
      ''');

    await database.execute('''
      CREATE INDEX index_facilities_category
      ON facilities (category)
      ''');

    await database.execute('''
      CREATE INDEX index_facilities_display_order
      ON facilities (
        park_id,
        area_id,
        display_order
      )
      ''');

    await database.execute('''
      CREATE INDEX index_facilities_operating
      ON facilities (
        park_id,
        is_operating
      )
      ''');

    await database.execute('''
      CREATE INDEX index_facilities_shop_type
      ON facilities (
        park_id,
        shop_type
      )
      ''');

    await database.execute('''
      CREATE INDEX index_facilities_restaurant_type
      ON facilities (
        park_id,
        restaurant_type
      )
      ''');

    await database.execute('''
      CREATE INDEX index_facilities_mobile_order
      ON facilities (
        park_id,
        supports_mobile_order
      )
      ''');

    await database.execute('''
      CREATE INDEX index_facilities_priority_seating
      ON facilities (
        park_id,
        supports_priority_seating
      )
      ''');

    await database.execute('''
      CREATE INDEX index_facilities_show_restaurant
      ON facilities (
        park_id,
        is_show_restaurant
      )
      ''');
  }

  static Future<void> _insertResort(DatabaseExecutor database) async {
    await database.insert('resorts', const {
      'id': 'tokyo_disney_resort',
      'name': '東京ディズニーリゾート',
      'country': 'Japan',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> close() async {
    final database = _database;

    if (database == null) {
      return;
    }

    await database.close();

    _database = null;
  }

  static Future<void> deleteDatabaseForDevelopment() async {
    _initializeDatabaseFactory();

    final databaseDirectory = await getDatabasesPath();

    final databasePath = path.join(databaseDirectory, databaseName);

    await close();

    await deleteDatabase(databasePath);
  }
}
