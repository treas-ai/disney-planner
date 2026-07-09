import '../../../../domain/entities/area.dart';
import '../../../../domain/entities/park.dart';
import '../../../../domain/entities/resort.dart';
import '../../../../domain/value_objects/coordinate.dart';
import '../../../../domain/value_objects/operating_hours.dart';

class MockParkDataSource {
  List<Resort> getResorts() {
    return const [
      Resort(
        id: 'tokyo_disney_resort',
        name: '東京ディズニーリゾート',
        country: 'Japan',
        parkIds: [
          'tokyo_disneyland',
          'tokyo_disneysea',
        ],
      ),
    ];
  }

  List<Park> getParks() {
    final today = DateTime.now();

    return [
      Park(
        id: 'tokyo_disneyland',
        resortId: 'tokyo_disney_resort',
        name: '東京ディズニーランド',
        areaIds: const [
          'tdl_world_bazaar',
          'tdl_adventureland',
          'tdl_westernland',
          'tdl_fantasyland',
          'tdl_tomorrowland',
        ],
        operatingHours: OperatingHours(
          open: DateTime(today.year, today.month, today.day, 9),
          close: DateTime(today.year, today.month, today.day, 21),
        ),
      ),
      Park(
        id: 'tokyo_disneysea',
        resortId: 'tokyo_disney_resort',
        name: '東京ディズニーシー',
        areaIds: const [
          'tds_mediterranean_harbor',
          'tds_american_waterfront',
          'tds_port_discovery',
          'tds_lost_river_delta',
          'tds_arabian_coast',
          'tds_mermaid_lagoon',
          'tds_mysterious_island',
          'tds_fantasy_springs',
        ],
        operatingHours: OperatingHours(
          open: DateTime(today.year, today.month, today.day, 9),
          close: DateTime(today.year, today.month, today.day, 21),
        ),
      ),
    ];
  }

  List<Area> getAreas() {
    return const [
      Area(
        id: 'tdl_world_bazaar',
        parkId: 'tokyo_disneyland',
        name: 'ワールドバザール',
        coordinate: Coordinate(latitude: 35.6329, longitude: 139.8804),
      ),
      Area(
        id: 'tdl_adventureland',
        parkId: 'tokyo_disneyland',
        name: 'アドベンチャーランド',
        coordinate: Coordinate(latitude: 35.6321, longitude: 139.8810),
      ),
      Area(
        id: 'tdl_westernland',
        parkId: 'tokyo_disneyland',
        name: 'ウエスタンランド',
        coordinate: Coordinate(latitude: 35.6324, longitude: 139.8796),
      ),
      Area(
        id: 'tdl_fantasyland',
        parkId: 'tokyo_disneyland',
        name: 'ファンタジーランド',
        coordinate: Coordinate(latitude: 35.6332, longitude: 139.8786),
      ),
      Area(
        id: 'tdl_tomorrowland',
        parkId: 'tokyo_disneyland',
        name: 'トゥモローランド',
        coordinate: Coordinate(latitude: 35.6334, longitude: 139.8817),
      ),
      Area(
        id: 'tds_mediterranean_harbor',
        parkId: 'tokyo_disneysea',
        name: 'メディテレーニアンハーバー',
        coordinate: Coordinate(latitude: 35.6267, longitude: 139.8850),
      ),
      Area(
        id: 'tds_american_waterfront',
        parkId: 'tokyo_disneysea',
        name: 'アメリカンウォーターフロント',
        coordinate: Coordinate(latitude: 35.6277, longitude: 139.8861),
      ),
      Area(
        id: 'tds_port_discovery',
        parkId: 'tokyo_disneysea',
        name: 'ポートディスカバリー',
        coordinate: Coordinate(latitude: 35.6293, longitude: 139.8868),
      ),
      Area(
        id: 'tds_lost_river_delta',
        parkId: 'tokyo_disneysea',
        name: 'ロストリバーデルタ',
        coordinate: Coordinate(latitude: 35.6301, longitude: 139.8847),
      ),
      Area(
        id: 'tds_arabian_coast',
        parkId: 'tokyo_disneysea',
        name: 'アラビアンコースト',
        coordinate: Coordinate(latitude: 35.6288, longitude: 139.8832),
      ),
      Area(
        id: 'tds_mermaid_lagoon',
        parkId: 'tokyo_disneysea',
        name: 'マーメイドラグーン',
        coordinate: Coordinate(latitude: 35.6280, longitude: 139.8827),
      ),
      Area(
        id: 'tds_mysterious_island',
        parkId: 'tokyo_disneysea',
        name: 'ミステリアスアイランド',
        coordinate: Coordinate(latitude: 35.6278, longitude: 139.8841),
      ),
      Area(
        id: 'tds_fantasy_springs',
        parkId: 'tokyo_disneysea',
        name: 'ファンタジースプリングス',
        coordinate: Coordinate(latitude: 35.6312, longitude: 139.8822),
      ),
    ];
  }
}