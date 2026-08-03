import '../entities/event_impact.dart';

abstract interface class EventImpactRepository {
  Future<List<EventImpact>> loadEventImpacts({required String parkId});
}
