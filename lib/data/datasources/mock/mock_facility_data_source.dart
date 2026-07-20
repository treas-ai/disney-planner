import '../../../domain/entities/facility.dart';
import '../../../domain/enums/facility_category.dart';
import '../../../domain/enums/priority_level.dart';
import '../../../domain/enums/reservation_type.dart';
import '../../../domain/value_objects/coordinate.dart';
import '../../../domain/value_objects/reservation.dart';
import '../../../domain/value_objects/wait_time.dart';
import '../facility_data_source.dart';

class MockFacilityDataSource implements FacilityDataSource {
  const MockFacilityDataSource();

  @override
  Future<List<Facility>> getFacilities() async {
    final now = DateTime.now();

    return [
      Facility(
        id: 'tdl_beauty_and_the_beast',
        parkId: 'tokyo_disneyland',
        areaId: 'tdl_fantasyland',
        name: '美女と野獣“魔法のものがたり”',
        category: FacilityCategory.attraction,
        coordinate: const Coordinate(latitude: 35.6331, longitude: 139.8788),
        waitTime: WaitTime(minutes: 80, updatedAt: now),
        reservation: const Reservation(type: ReservationType.dpa),
        priority: PriorityLevel.high,
        description: '映画「美女と野獣」の世界を体験できる大型アトラクションです。',
      ),
      Facility(
        id: 'tdl_grand_emporium',
        parkId: 'tokyo_disneyland',
        areaId: 'tdl_world_bazaar',
        name: 'グランドエンポーリアム',
        category: FacilityCategory.shop,
        coordinate: const Coordinate(latitude: 35.6329, longitude: 139.8802),
        waitTime: WaitTime(minutes: 0, updatedAt: now),
        priority: PriorityLevel.medium,
        description: '東京ディズニーランド最大級のショップです。',
      ),
      Facility(
        id: 'tds_soaring',
        parkId: 'tokyo_disneysea',
        areaId: 'tds_mediterranean_harbor',
        name: 'ソアリン：ファンタスティック・フライト',
        category: FacilityCategory.attraction,
        coordinate: const Coordinate(latitude: 35.6268, longitude: 139.8855),
        waitTime: WaitTime(minutes: 95, updatedAt: now),
        reservation: const Reservation(type: ReservationType.dpa),
        priority: PriorityLevel.highest,
        description: '空を飛ぶような体験ができる東京ディズニーシーの人気アトラクションです。',
      ),
      Facility(
        id: 'tds_big_band_beat',
        parkId: 'tokyo_disneysea',
        areaId: 'tds_american_waterfront',
        name: 'ビッグバンドビート',
        category: FacilityCategory.show,
        coordinate: const Coordinate(latitude: 35.6278, longitude: 139.8860),
        reservation: const Reservation(type: ReservationType.entryRequest),
        priority: PriorityLevel.high,
        description: 'ブロードウェイ・ミュージックシアターで公演されるショーです。',
      ),
      Facility(
        id: 'tds_magellans',
        parkId: 'tokyo_disneysea',
        areaId: 'tds_mediterranean_harbor',
        name: 'マゼランズ',
        category: FacilityCategory.restaurant,
        coordinate: const Coordinate(latitude: 35.6269, longitude: 139.8848),
        reservation: const Reservation(type: ReservationType.standby),
        priority: PriorityLevel.medium,
        description: 'メディテレーニアンハーバーにある高級感のあるレストランです。',
      ),
    ];
  }

  @override
  Future<List<Facility>> getFacilitiesByParkId(String parkId) async {
    final facilities = await getFacilities();

    return facilities.where((facility) => facility.parkId == parkId).toList();
  }

  @override
  Future<List<Facility>> getFacilitiesByAreaId(String areaId) async {
    final facilities = await getFacilities();

    return facilities.where((facility) => facility.areaId == areaId).toList();
  }

  @override
  Future<List<Facility>> getFacilitiesByCategory(
    FacilityCategory category,
  ) async {
    final facilities = await getFacilities();

    return facilities
        .where((facility) => facility.category == category)
        .toList();
  }

  @override
  Future<Facility?> getFacilityById(String facilityId) async {
    final facilities = await getFacilities();

    for (final facility in facilities) {
      if (facility.id == facilityId) {
        return facility;
      }
    }

    return null;
  }
}
