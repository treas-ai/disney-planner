import '../../domain/entities/attraction_operation.dart';
import '../../domain/entities/crowd_snapshot.dart';
import '../../domain/entities/entertainment_operation.dart';
import '../../domain/entities/live_operation_snapshot.dart';
import '../../domain/entities/park_operation.dart';
import '../../domain/entities/restaurant_operation.dart';
import '../../domain/entities/weather_snapshot.dart';
import '../../domain/enums/live_crowd_level.dart';
import '../../domain/enums/live_operation_availability.dart';
import '../../domain/enums/live_weather_condition.dart';
import '../../domain/enums/live_data_source_type.dart';
import '../../domain/providers/live_data_provider.dart';

class MockLiveDataProvider implements LiveDataProvider {
  const MockLiveDataProvider();

  @override
  LiveDataSourceType get sourceType => LiveDataSourceType.mock;

  @override
  Future<LiveOperationSnapshot> fetchSnapshot({required String parkId}) async {
    final now = DateTime.now();
    final isSea = parkId == 'tokyo_disneysea';

    return LiveOperationSnapshot(
      parkId: parkId,
      updatedAt: now,
      isMock: true,
      sourceType: LiveDataSourceType.mock,
      parkOperation: ParkOperation(
        parkId: parkId,
        openTime: '09:00',
        closeTime: '21:00',
        happyEntryAvailable: true,
        updatedAt: now,
        note: '開園時間はMock表示です。公式アプリで確認してください。',
      ),
      weather: WeatherSnapshot(
        condition: LiveWeatherCondition.sunny,
        temperatureCelsius: 28,
        precipitationMillimeters: 0,
        windSpeedMetersPerSecond: 3.2,
        updatedAt: now,
      ),
      crowd: CrowdSnapshot(
        parkId: parkId,
        parkLevel: LiveCrowdLevel.moderate,
        peakTimeLabel: '13:00〜16:00（Mock）',
        updatedAt: now,
      ),
      attractions: [
        AttractionOperation(
          parkId: parkId,
          facilityId: isSea ? 'tds_soaring' : 'tdl_beauty_and_beast',
          availability: LiveOperationAvailability.operating,
          standbyMinutes: isSea ? 55 : 70,
          dpaAvailable: true,
          updatedAt: now,
          note: 'Mockデータ',
        ),
        AttractionOperation(
          parkId: parkId,
          facilityId: isSea
              ? 'tds_tower_of_terror'
              : 'tdl_big_thunder_mountain',
          availability: LiveOperationAvailability.operating,
          standbyMinutes: isSea ? 40 : 35,
          updatedAt: now,
          note: 'Mockデータ',
        ),
      ],
      restaurants: [
        RestaurantOperation(
          parkId: parkId,
          facilityId: isSea ? 'tds_casbah_food_court' : 'tdl_plazapavilion',
          availability: LiveOperationAvailability.operating,
          mobileOrderAvailable: true,
          acceptingOrders: true,
          seatAvailabilityLabel: '通常（Mock）',
          updatedAt: now,
          note: 'Mockデータ',
        ),
      ],
      entertainment: [
        EntertainmentOperation(
          parkId: parkId,
          facilityId: isSea ? 'tds_believe' : 'tdl_magical_music_world',
          availability: LiveOperationAvailability.operating,
          entryRequestAvailable: !isSea,
          freeSeatingAvailable: false,
          queueOpen: true,
          nextPerformanceTime: '19:30（Mock）',
          updatedAt: now,
          note: 'Mockデータ',
        ),
      ],
    );
  }
}
