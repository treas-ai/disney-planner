import '../entities/event_impact.dart';

class EventImpactEngine {
  const EventImpactEngine();

  List<EventImpact> activeImpacts({
    required int atMinutes,
    required List<EventImpact> impacts,
  }) {
    return List<EventImpact>.unmodifiable(
      impacts.where((impact) => impact.isActiveAtMinutes(atMinutes)),
    );
  }

  int movementPenaltyMinutes({
    required String fromAreaId,
    required String toAreaId,
    required int atMinutes,
    required List<EventImpact> impacts,
  }) {
    var penalty = 0;

    for (final impact in activeImpacts(
      atMinutes: atMinutes,
      impacts: impacts,
    )) {
      if (impact.affectsArea(fromAreaId) || impact.affectsArea(toAreaId)) {
        penalty += impact.movementPenaltyMinutes;
      }
    }

    return penalty;
  }

  bool isRouteBlocked({
    required String fromAreaId,
    required String toAreaId,
    required int atMinutes,
    required List<EventImpact> impacts,
  }) {
    return activeImpacts(
      atMinutes: atMinutes,
      impacts: impacts,
    ).any((impact) => impact.blocksRoute(fromAreaId, toAreaId));
  }

  List<String> warnings({
    required int atMinutes,
    required List<EventImpact> impacts,
  }) {
    return List<String>.unmodifiable(
      activeImpacts(atMinutes: atMinutes, impacts: impacts).map((impact) {
        final note = impact.note?.trim();
        return note == null || note.isEmpty
            ? '${impact.eventName}による移動影響があります。'
            : '${impact.eventName}：$note';
      }),
    );
  }
}
