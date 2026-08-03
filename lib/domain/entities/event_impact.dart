import '../enums/event_impact_level.dart';

class EventImpact {
  const EventImpact({
    required this.id,
    required this.parkId,
    required this.eventName,
    required this.startTime,
    required this.endTime,
    required this.affectedAreaIds,
    required this.blockedRouteKeys,
    required this.movementPenaltyMinutes,
    required this.level,
    required this.enabled,
    this.eventFacilityId,
    this.note,
    this.officialSourceUrl,
    this.verifiedAt,
  });

  factory EventImpact.fromJson(Map<String, dynamic> json) {
    return EventImpact(
      id: json['id'] as String? ?? '',
      parkId: json['parkId'] as String? ?? '',
      eventName: json['eventName'] as String? ?? '',
      eventFacilityId: json['eventFacilityId'] as String?,
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      affectedAreaIds: List<String>.unmodifiable(
        (json['affectedAreaIds'] as List? ?? const []).whereType<String>(),
      ),
      blockedRouteKeys: List<String>.unmodifiable(
        (json['blockedRouteKeys'] as List? ?? const []).whereType<String>(),
      ),
      movementPenaltyMinutes: json['movementPenaltyMinutes'] as int? ?? 0,
      level: EventImpactLevel.values.firstWhere(
        (value) => value.name == json['level'],
        orElse: () => EventImpactLevel.low,
      ),
      enabled: json['enabled'] as bool? ?? false,
      note: json['note'] as String?,
      officialSourceUrl: json['officialSourceUrl'] as String?,
      verifiedAt: json['verifiedAt'] as String?,
    );
  }

  final String id;
  final String parkId;
  final String eventName;
  final String? eventFacilityId;
  final String startTime;
  final String endTime;
  final List<String> affectedAreaIds;
  final List<String> blockedRouteKeys;
  final int movementPenaltyMinutes;
  final EventImpactLevel level;
  final bool enabled;
  final String? note;
  final String? officialSourceUrl;
  final String? verifiedAt;

  int? get startMinutes => _parseMinutes(startTime);
  int? get endMinutes => _parseMinutes(endTime);

  bool isActiveAtMinutes(int minutes) {
    if (!enabled) {
      return false;
    }

    final start = startMinutes;
    final end = endMinutes;
    if (start == null || end == null) {
      return false;
    }

    if (end >= start) {
      return minutes >= start && minutes < end;
    }

    return minutes >= start || minutes < end;
  }

  bool affectsArea(String areaId) => affectedAreaIds.contains(areaId);

  bool blocksRoute(String fromAreaId, String toAreaId) {
    final direct = '$fromAreaId->$toAreaId';
    final reverse = '$toAreaId->$fromAreaId';
    return blockedRouteKeys.contains(direct) ||
        blockedRouteKeys.contains(reverse);
  }

  static int? _parseMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return hour * 60 + minute;
  }
}
