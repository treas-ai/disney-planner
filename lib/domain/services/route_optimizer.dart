import '../entities/facility.dart';
import '../entities/plan_preference.dart';
import '../enums/preferred_time.dart';
import 'facility_proximity_service.dart';

class RouteOptimizer {
  const RouteOptimizer({
    this.proximityService = const FacilityProximityService(),
  });

  final FacilityProximityService proximityService;

  List<Facility> optimize({
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
  }) {
    if (facilities.length <= 1) {
      return List.unmodifiable(facilities);
    }

    final indexedFacilities = facilities.indexed
        .map(
          (entry) => _IndexedFacility(
            originalIndex: entry.$1,
            facility: entry.$2,
            preference: _findPreference(
              facilityId: entry.$2.id,
              preferences: preferences,
            ),
          ),
        )
        .toList();

    indexedFacilities.sort(_compareFacilities);
    final proximityOptimized = _optimizeLocalRuns(indexedFacilities);

    return List.unmodifiable(
      proximityOptimized.map((item) => item.facility).toList(),
    );
  }

  List<_IndexedFacility> _optimizeLocalRuns(List<_IndexedFacility> sorted) {
    final result = <_IndexedFacility>[];
    var index = 0;
    while (index < sorted.length) {
      final first = sorted[index];
      var end = index + 1;
      while (end < sorted.length && _sameLocalRun(first, sorted[end])) {
        end++;
      }

      final run = sorted.sublist(index, end);
      if (run.length <= 2) {
        result.addAll(run);
      } else {
        // 最初の候補は既存ロジックの判断を尊重し、その後だけ近い順にする。
        final remaining = run.sublist(1).toList();
        var current = run.first;
        result.add(current);
        while (remaining.isNotEmpty) {
          remaining.sort((a, b) {
            final aDistance = proximityService.distanceMeters(
              current.facility,
              a.facility,
            );
            final bDistance = proximityService.distanceMeters(
              current.facility,
              b.facility,
            );
            final distanceCompare = aDistance.compareTo(bDistance);
            if (distanceCompare != 0) return distanceCompare;
            return a.originalIndex.compareTo(b.originalIndex);
          });
          current = remaining.removeAt(0);
          result.add(current);
        }
      }
      index = end;
    }
    return result;
  }

  bool _sameLocalRun(_IndexedFacility a, _IndexedFacility b) {
    if (a.facility.areaId != b.facility.areaId) return false;
    if (_preferredTimeScore(a.preference?.preferredTime) !=
        _preferredTimeScore(b.preference?.preferredTime)) {
      return false;
    }
    final aPriority = a.preference?.priority.value ?? a.facility.priority.value;
    final bPriority = b.preference?.priority.value ?? b.facility.priority.value;
    return aPriority == bPriority;
  }

  int _compareFacilities(_IndexedFacility first, _IndexedFacility second) {
    final preferredTimeComparison = _preferredTimeScore(
      first.preference?.preferredTime,
    ).compareTo(_preferredTimeScore(second.preference?.preferredTime));

    if (preferredTimeComparison != 0) {
      return preferredTimeComparison;
    }

    // 早く営業終了する施設は、同じ希望時間帯の中で後回しにしすぎない。
    // 朝一アトラクションはScheduleEngine側で別途保護される。
    final closingComparison = _closingUrgencyScore(
      first.facility,
    ).compareTo(_closingUrgencyScore(second.facility));
    if (closingComparison != 0) {
      return closingComparison;
    }

    final areaComparison = first.facility.areaId.compareTo(
      second.facility.areaId,
    );

    if (areaComparison != 0) {
      return areaComparison;
    }

    final firstPriority =
        first.preference?.priority.value ?? first.facility.priority.value;

    final secondPriority =
        second.preference?.priority.value ?? second.facility.priority.value;

    final priorityComparison = secondPriority.compareTo(firstPriority);

    if (priorityComparison != 0) {
      return priorityComparison;
    }

    return first.originalIndex.compareTo(second.originalIndex);
  }

  int _closingUrgencyScore(Facility facility) {
    final hours = facility.operatingHours;
    if (hours == null) return 24 * 60;

    final closeMinutes = hours.close.hour * 60 + hours.close.minute;
    // 18時以前に終了する施設のみ明確な「早仕舞い」として優先する。
    return closeMinutes <= 18 * 60 ? closeMinutes : 24 * 60;
  }

  int _preferredTimeScore(PreferredTime? preferredTime) {
    return switch (preferredTime) {
      PreferredTime.morning => 0,
      PreferredTime.anytime || null => 1,
      PreferredTime.afternoon => 2,
      PreferredTime.evening => 3,
    };
  }

  PlanPreference? _findPreference({
    required String facilityId,
    required List<PlanPreference> preferences,
  }) {
    for (final preference in preferences) {
      if (preference.facilityId == facilityId) {
        return preference;
      }
    }

    return null;
  }
}

class _IndexedFacility {
  const _IndexedFacility({
    required this.originalIndex,
    required this.facility,
    required this.preference,
  });

  final int originalIndex;
  final Facility facility;
  final PlanPreference? preference;
}
