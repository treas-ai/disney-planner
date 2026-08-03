import '../entities/area_connection.dart';
import '../entities/movement_estimate.dart';

class MovementTimeEngine {
  const MovementTimeEngine({this.fallbackMinutes = 10});

  final int fallbackMinutes;

  MovementEstimate estimate({
    required String fromAreaId,
    required String toAreaId,
    required DateTime departureAt,
    required List<AreaConnection> connections,
  }) {
    if (fromAreaId == toAreaId) {
      return MovementEstimate(
        fromAreaId: fromAreaId,
        toAreaId: toAreaId,
        minutes: 0,
        arrivalAt: departureAt,
        isFallback: false,
        pathAreaIds: List<String>.unmodifiable([fromAreaId]),
      );
    }

    final result = _shortestPath(
      fromAreaId: fromAreaId,
      toAreaId: toAreaId,
      connections: connections,
    );

    final minutes = result?.minutes ?? fallbackMinutes;

    return MovementEstimate(
      fromAreaId: fromAreaId,
      toAreaId: toAreaId,
      minutes: minutes,
      arrivalAt: departureAt.add(Duration(minutes: minutes)),
      isFallback: result == null,
      pathAreaIds: List<String>.unmodifiable(
        result?.pathAreaIds ?? [fromAreaId, toAreaId],
      ),
    );
  }

  _PathResult? _shortestPath({
    required String fromAreaId,
    required String toAreaId,
    required List<AreaConnection> connections,
  }) {
    final areaIds = <String>{fromAreaId, toAreaId};

    for (final connection in connections) {
      areaIds
        ..add(connection.fromAreaId)
        ..add(connection.toAreaId);
    }

    final distances = <String, int>{
      for (final areaId in areaIds) areaId: 1 << 30,
      fromAreaId: 0,
    };
    final previous = <String, String>{};
    final unvisited = areaIds.toSet();

    while (unvisited.isNotEmpty) {
      String? current;
      var currentDistance = 1 << 30;

      for (final areaId in unvisited) {
        final distance = distances[areaId] ?? (1 << 30);
        if (distance < currentDistance) {
          current = areaId;
          currentDistance = distance;
        }
      }

      if (current == null || currentDistance == (1 << 30)) {
        break;
      }

      if (current == toAreaId) {
        break;
      }

      unvisited.remove(current);

      for (final connection in connections) {
        final neighbor = _neighborFor(connection, current);
        if (neighbor == null || !unvisited.contains(neighbor)) {
          continue;
        }

        final nextDistance = currentDistance + connection.minutes;
        if (nextDistance < (distances[neighbor] ?? (1 << 30))) {
          distances[neighbor] = nextDistance;
          previous[neighbor] = current;
        }
      }
    }

    final totalMinutes = distances[toAreaId];
    if (totalMinutes == null || totalMinutes == (1 << 30)) {
      return null;
    }

    final reversedPath = <String>[toAreaId];
    var cursor = toAreaId;

    while (cursor != fromAreaId) {
      final previousAreaId = previous[cursor];
      if (previousAreaId == null) {
        return null;
      }

      reversedPath.add(previousAreaId);
      cursor = previousAreaId;
    }

    return _PathResult(
      minutes: totalMinutes,
      pathAreaIds: reversedPath.reversed.toList(growable: false),
    );
  }

  String? _neighborFor(AreaConnection connection, String currentAreaId) {
    if (connection.fromAreaId == currentAreaId) {
      return connection.toAreaId;
    }

    if (connection.bidirectional && connection.toAreaId == currentAreaId) {
      return connection.fromAreaId;
    }

    return null;
  }
}

class _PathResult {
  const _PathResult({required this.minutes, required this.pathAreaIds});

  final int minutes;
  final List<String> pathAreaIds;
}
