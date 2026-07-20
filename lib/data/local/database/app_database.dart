import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._();

  static const String databaseName = 'disney_planner.db';
  static const int databaseVersion = 1;

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
      await _insertInitialData(transaction);
    });
  }

  static Future<void> _onUpgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    // v1.3ではデータベースVersion 1のみを使用します。
    //
    // 将来Version 2以降へ変更する場合は、次のように
    // oldVersionを確認してMigrationを追加します。
    //
    // if (oldVersion < 2) {
    //   await database.execute(
    //     'ALTER TABLE facilities ADD COLUMN image_url TEXT',
    //   );
    // }
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
  }

  static Future<void> _insertInitialData(DatabaseExecutor database) async {
    await _insertResorts(database);
    await _insertParks(database);
    await _insertAreas(database);
    await _insertFacilities(database);
  }

  static Future<void> _insertResorts(DatabaseExecutor database) async {
    await database.insert('resorts', {
      'id': 'tokyo_disney_resort',
      'name': '東京ディズニーリゾート',
      'country': 'Japan',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> _insertParks(DatabaseExecutor database) async {
    final parks = [
      {
        'id': 'tokyo_disneyland',
        'resort_id': 'tokyo_disney_resort',
        'name': '東京ディズニーランド',
        'open_hour': 9,
        'open_minute': 0,
        'close_hour': 21,
        'close_minute': 0,
        'status': 'open',
      },
      {
        'id': 'tokyo_disneysea',
        'resort_id': 'tokyo_disney_resort',
        'name': '東京ディズニーシー',
        'open_hour': 9,
        'open_minute': 0,
        'close_hour': 21,
        'close_minute': 0,
        'status': 'open',
      },
    ];

    for (final park in parks) {
      await database.insert(
        'parks',
        park,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  static Future<void> _insertAreas(DatabaseExecutor database) async {
    final areas = [
      {
        'id': 'tdl_world_bazaar',
        'park_id': 'tokyo_disneyland',
        'name': 'ワールドバザール',
        'latitude': 35.6329,
        'longitude': 139.8804,
      },
      {
        'id': 'tdl_adventureland',
        'park_id': 'tokyo_disneyland',
        'name': 'アドベンチャーランド',
        'latitude': 35.6321,
        'longitude': 139.8810,
      },
      {
        'id': 'tdl_westernland',
        'park_id': 'tokyo_disneyland',
        'name': 'ウエスタンランド',
        'latitude': 35.6324,
        'longitude': 139.8796,
      },
      {
        'id': 'tdl_fantasyland',
        'park_id': 'tokyo_disneyland',
        'name': 'ファンタジーランド',
        'latitude': 35.6332,
        'longitude': 139.8786,
      },
      {
        'id': 'tdl_tomorrowland',
        'park_id': 'tokyo_disneyland',
        'name': 'トゥモローランド',
        'latitude': 35.6334,
        'longitude': 139.8817,
      },
      {
        'id': 'tds_mediterranean_harbor',
        'park_id': 'tokyo_disneysea',
        'name': 'メディテレーニアンハーバー',
        'latitude': 35.6267,
        'longitude': 139.8850,
      },
      {
        'id': 'tds_american_waterfront',
        'park_id': 'tokyo_disneysea',
        'name': 'アメリカンウォーターフロント',
        'latitude': 35.6277,
        'longitude': 139.8861,
      },
      {
        'id': 'tds_port_discovery',
        'park_id': 'tokyo_disneysea',
        'name': 'ポートディスカバリー',
        'latitude': 35.6293,
        'longitude': 139.8868,
      },
      {
        'id': 'tds_lost_river_delta',
        'park_id': 'tokyo_disneysea',
        'name': 'ロストリバーデルタ',
        'latitude': 35.6301,
        'longitude': 139.8847,
      },
      {
        'id': 'tds_arabian_coast',
        'park_id': 'tokyo_disneysea',
        'name': 'アラビアンコースト',
        'latitude': 35.6288,
        'longitude': 139.8832,
      },
      {
        'id': 'tds_mermaid_lagoon',
        'park_id': 'tokyo_disneysea',
        'name': 'マーメイドラグーン',
        'latitude': 35.6280,
        'longitude': 139.8827,
      },
      {
        'id': 'tds_mysterious_island',
        'park_id': 'tokyo_disneysea',
        'name': 'ミステリアスアイランド',
        'latitude': 35.6278,
        'longitude': 139.8841,
      },
      {
        'id': 'tds_fantasy_springs',
        'park_id': 'tokyo_disneysea',
        'name': 'ファンタジースプリングス',
        'latitude': 35.6312,
        'longitude': 139.8822,
      },
    ];

    for (final area in areas) {
      await database.insert(
        'areas',
        area,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  static Future<void> _insertFacilities(DatabaseExecutor database) async {
    final initialTimestamp = DateTime.now().toIso8601String();

    final facilities = [
      {
        'id': 'tdl_beauty_and_the_beast',
        'park_id': 'tokyo_disneyland',
        'area_id': 'tdl_fantasyland',
        'name': '美女と野獣“魔法のものがたり”',
        'category': 'attraction',
        'latitude': 35.6331,
        'longitude': 139.8788,
        'open_hour': null,
        'open_minute': null,
        'close_hour': null,
        'close_minute': null,
        'priority': 'high',
        'status': 'open',
        'description': '映画「美女と野獣」の世界を体験できる大型アトラクションです。',
        'reservation_type': 'dpa',
        'reservation_time': null,
        'wait_minutes': 80,
        'wait_updated_at': initialTimestamp,
      },
      {
        'id': 'tdl_grand_emporium',
        'park_id': 'tokyo_disneyland',
        'area_id': 'tdl_world_bazaar',
        'name': 'グランドエンポーリアム',
        'category': 'shop',
        'latitude': 35.6329,
        'longitude': 139.8802,
        'open_hour': null,
        'open_minute': null,
        'close_hour': null,
        'close_minute': null,
        'priority': 'medium',
        'status': 'open',
        'description': '東京ディズニーランド最大級のショップです。',
        'reservation_type': null,
        'reservation_time': null,
        'wait_minutes': 0,
        'wait_updated_at': initialTimestamp,
      },
      {
        'id': 'tds_soaring',
        'park_id': 'tokyo_disneysea',
        'area_id': 'tds_mediterranean_harbor',
        'name': 'ソアリン：ファンタスティック・フライト',
        'category': 'attraction',
        'latitude': 35.6268,
        'longitude': 139.8855,
        'open_hour': null,
        'open_minute': null,
        'close_hour': null,
        'close_minute': null,
        'priority': 'highest',
        'status': 'open',
        'description': '空を飛ぶような体験ができる東京ディズニーシーの人気アトラクションです。',
        'reservation_type': 'dpa',
        'reservation_time': null,
        'wait_minutes': 95,
        'wait_updated_at': initialTimestamp,
      },
      {
        'id': 'tds_big_band_beat',
        'park_id': 'tokyo_disneysea',
        'area_id': 'tds_american_waterfront',
        'name': 'ビッグバンドビート',
        'category': 'show',
        'latitude': 35.6278,
        'longitude': 139.8860,
        'open_hour': null,
        'open_minute': null,
        'close_hour': null,
        'close_minute': null,
        'priority': 'high',
        'status': 'open',
        'description': 'ブロードウェイ・ミュージックシアターで公演されるショーです。',
        'reservation_type': 'entryRequest',
        'reservation_time': null,
        'wait_minutes': null,
        'wait_updated_at': null,
      },
      {
        'id': 'tds_magellans',
        'park_id': 'tokyo_disneysea',
        'area_id': 'tds_mediterranean_harbor',
        'name': 'マゼランズ',
        'category': 'restaurant',
        'latitude': 35.6269,
        'longitude': 139.8848,
        'open_hour': null,
        'open_minute': null,
        'close_hour': null,
        'close_minute': null,
        'priority': 'medium',
        'status': 'open',
        'description': 'メディテレーニアンハーバーにある高級感のあるレストランです。',
        'reservation_type': 'standby',
        'reservation_time': null,
        'wait_minutes': null,
        'wait_updated_at': null,
      },
    ];

    for (final facility in facilities) {
      await database.insert(
        'facilities',
        facility,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
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
