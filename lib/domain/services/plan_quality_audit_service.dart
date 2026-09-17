import '../entities/area_connection.dart';
import '../entities/day_schedule.dart';
import '../entities/facility.dart';
import '../entities/facility_location.dart';
import '../entities/schedule_item.dart';
import '../enums/schedule_item_type.dart';

class PlanQualityAudit {
  const PlanQualityAudit({
    required this.totalWaitMinutes,
    required this.totalFreeMinutes,
    required this.largestFreeBlockMinutes,
    required this.freeBlockCount,
    required this.smallFreeBlockCount,
    required this.minimumGapMinutes,
    required this.overlapCount,
    required this.totalMovementMinutes,
    required this.areaCrossingCount,
    required this.areaRevisitCount,
    required this.delay5Safe,
    required this.delay10Safe,
    required this.delay20Safe,
    required this.robustnessLevel,
    required this.robustnessMessage,
  });

  final int totalWaitMinutes;
  final int totalFreeMinutes;
  final int largestFreeBlockMinutes;
  final int freeBlockCount;
  final int smallFreeBlockCount;
  final int minimumGapMinutes;
  final int overlapCount;
  final int totalMovementMinutes;
  final int areaCrossingCount;
  final int areaRevisitCount;
  final bool delay5Safe;
  final bool delay10Safe;
  final bool delay20Safe;
  final String robustnessLevel;
  final String robustnessMessage;
}

class PlanQualityAuditService {
  const PlanQualityAuditService();

  PlanQualityAudit evaluate(
    DaySchedule schedule, {
    List<Facility> facilities = const [],
    List<FacilityLocation> facilityLocations = const [],
    List<AreaConnection> areaConnections = const [],
  }) {
    final items = [...schedule.items]..sort((a, b) => _start(a).compareTo(_start(b)));
    var wait = 0;
    var free = 0;
    var largestFree = 0;
    var freeBlocks = 0;
    var smallFree = 0;
    var overlaps = 0;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      wait += item.effectiveQueueMinutes ?? 0;
      if (item.type == ScheduleItemType.breakTime) {
        final rawDuration = _end(item) - _start(item);
        final duration = rawDuration.clamp(0, 24 * 60).toInt();
        free += duration;
        freeBlocks++;
        if (duration > largestFree) largestFree = duration;
        if (duration < 30) smallFree++;
      }
      if (i > 0 && _start(item) < _end(items[i - 1])) overlaps++;
    }

    final active = items
        .where((item) =>
            item.type != ScheduleItemType.breakTime &&
            item.type != ScheduleItemType.entry &&
            item.type != ScheduleItemType.exit)
        .toList(growable: false);
    int? minimumGap;
    for (var i = 1; i < active.length; i++) {
      final gap = _start(active[i]) - _end(active[i - 1]);
      if (gap < 0) continue;
      minimumGap = minimumGap == null ? gap : (gap < minimumGap ? gap : minimumGap);
    }
    final minGap = minimumGap ?? 0;

    final facilityById = {for (final facility in facilities) facility.id: facility};
    final locationById = {for (final location in facilityLocations) location.facilityId: location};
    var movement = 0;
    var crossings = 0;
    var revisits = 0;
    final seenAreas = <String>{};
    String? previousArea;
    for (final item in active) {
      final entryArea = _entryArea(item, facilityById, locationById);
      if (entryArea != null) {
        if (previousArea != null) {
          movement += _movementMinutes(previousArea, entryArea, areaConnections);
          if (previousArea != entryArea) {
            crossings++;
            if (seenAreas.contains(entryArea)) revisits++;
          }
        }
        seenAreas.add(entryArea);
      }
      previousArea = _exitArea(item, facilityById, locationById) ?? entryArea ?? previousArea;
      if (previousArea != null) seenAreas.add(previousArea);
    }

    // This is deliberately a timeline stress check, not a second optimizer.
    // It asks whether adding the same delay to completion of each ordinary
    // planned item would collide with the next planned start. It therefore
    // exposes brittle schedules without changing schedule generation.
    bool survivesDelay(int delay) {
      if (overlaps > 0) return false;
      for (var i = 1; i < active.length; i++) {
        final gap = _start(active[i]) - _end(active[i - 1]);
        if (gap < delay) return false;
      }
      return true;
    }

    final delay5 = survivesDelay(5);
    final delay10 = survivesDelay(10);
    final delay20 = survivesDelay(20);
    final (level, message) = switch ((overlaps, delay5, delay10, delay20)) {
      (> 0, _, _, _) => ('要確認', '予定の重なりがあります。固定予定と移動条件を確認してください。'),
      (0, false, _, _) => ('余裕少なめ', '5分の一律遅延でも次予定へ影響する区間があります。'),
      (0, true, false, _) => ('余裕少なめ', '5分遅延には耐えますが、10分遅延では次予定へ影響する区間があります。'),
      (0, true, true, false) => ('標準', '10分遅延までは吸収できますが、20分遅延では次予定へ影響する区間があります。'),
      _ => ('余裕あり', '20分の一律遅延ストレスでも次予定との重なりは発生しません。'),
    };

    return PlanQualityAudit(
      totalWaitMinutes: wait,
      totalFreeMinutes: free,
      largestFreeBlockMinutes: largestFree,
      freeBlockCount: freeBlocks,
      smallFreeBlockCount: smallFree,
      minimumGapMinutes: minGap,
      overlapCount: overlaps,
      totalMovementMinutes: movement,
      areaCrossingCount: crossings,
      areaRevisitCount: revisits,
      delay5Safe: delay5,
      delay10Safe: delay10,
      delay20Safe: delay20,
      robustnessLevel: level,
      robustnessMessage: message,
    );
  }

  String? _entryArea(
    ScheduleItem item,
    Map<String, Facility> facilityById,
    Map<String, FacilityLocation> locationById,
  ) {
    final id = item.facilityId;
    if (id == null || id.isEmpty) return null;
    return locationById[id]?.areaId ?? facilityById[id]?.areaId;
  }

  String? _exitArea(
    ScheduleItem item,
    Map<String, Facility> facilityById,
    Map<String, FacilityLocation> locationById,
  ) {
    final id = item.facilityId;
    if (id == null || id.isEmpty) return null;
    return locationById[id]?.effectiveExitAreaId ?? facilityById[id]?.areaId;
  }

  int _movementMinutes(String from, String to, List<AreaConnection> connections) {
    if (from == to) return 5;
    if (connections.isEmpty) return 15;
    final distances = <String, int>{from: 0};
    final visited = <String>{};
    while (true) {
      String? current;
      var currentDistance = 1 << 30;
      for (final entry in distances.entries) {
        if (!visited.contains(entry.key) && entry.value < currentDistance) {
          current = entry.key;
          currentDistance = entry.value;
        }
      }
      if (current == null) return 15;
      if (current == to) return currentDistance;
      visited.add(current);
      for (final connection in connections) {
        String? next;
        if (connection.fromAreaId == current) {
          next = connection.toAreaId;
        } else if (connection.bidirectional && connection.toAreaId == current) {
          next = connection.fromAreaId;
        }
        if (next == null || connection.minutes <= 0) continue;
        final candidate = currentDistance + connection.minutes;
        if (candidate < (distances[next] ?? (1 << 30))) distances[next] = candidate;
      }
    }
  }

  int _start(ScheduleItem item) => item.startHour * 60 + item.startMinute;
  int _end(ScheduleItem item) => item.endHour * 60 + item.endMinute;
}
