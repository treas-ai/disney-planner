import '../enums/live_data_source_type.dart';
import 'attraction_operation.dart';
import 'crowd_snapshot.dart';
import 'entertainment_operation.dart';
import 'park_operation.dart';
import 'restaurant_operation.dart';
import 'weather_snapshot.dart';

class LiveOperationSnapshot {
  const LiveOperationSnapshot({
    required this.parkId,
    required this.updatedAt,
    this.parkOperation,
    this.weather,
    this.crowd,
    this.attractions = const [],
    this.restaurants = const [],
    this.entertainment = const [],
    this.isMock = false,
    this.sourceType = LiveDataSourceType.mock,
    this.fromCache = false,
    this.fallbackMessage,
  });

  final String parkId;
  final DateTime updatedAt;
  final ParkOperation? parkOperation;
  final WeatherSnapshot? weather;
  final CrowdSnapshot? crowd;
  final List<AttractionOperation> attractions;
  final List<RestaurantOperation> restaurants;
  final List<EntertainmentOperation> entertainment;
  final bool isMock;
  final LiveDataSourceType sourceType;
  final bool fromCache;
  final String? fallbackMessage;

  bool get hasData =>
      parkOperation != null ||
      weather != null ||
      crowd != null ||
      attractions.isNotEmpty ||
      restaurants.isNotEmpty ||
      entertainment.isNotEmpty;

  String get sourceLabel {
    final cacheSuffix = fromCache ? '・キャッシュ' : '';
    return '${sourceType.label}$cacheSuffix';
  }

  LiveOperationSnapshot copyWith({
    DateTime? updatedAt,
    bool? isMock,
    LiveDataSourceType? sourceType,
    bool? fromCache,
    String? fallbackMessage,
  }) {
    return LiveOperationSnapshot(
      parkId: parkId,
      updatedAt: updatedAt ?? this.updatedAt,
      parkOperation: parkOperation,
      weather: weather,
      crowd: crowd,
      attractions: attractions,
      restaurants: restaurants,
      entertainment: entertainment,
      isMock: isMock ?? this.isMock,
      sourceType: sourceType ?? this.sourceType,
      fromCache: fromCache ?? this.fromCache,
      fallbackMessage: fallbackMessage ?? this.fallbackMessage,
    );
  }
}
