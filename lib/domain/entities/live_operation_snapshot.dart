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

  bool get hasData =>
      parkOperation != null ||
      weather != null ||
      crowd != null ||
      attractions.isNotEmpty ||
      restaurants.isNotEmpty ||
      entertainment.isNotEmpty;
}
