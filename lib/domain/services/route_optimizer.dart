import '../entities/facility.dart';
import '../entities/plan_preference.dart';
import '../enums/preferred_time.dart';

class RouteOptimizer {
  const RouteOptimizer();

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

    return List.unmodifiable(
      indexedFacilities.map((item) => item.facility).toList(),
    );
  }

  int _compareFacilities(_IndexedFacility first, _IndexedFacility second) {
    final preferredTimeComparison = _preferredTimeScore(
      first.preference?.preferredTime,
    ).compareTo(_preferredTimeScore(second.preference?.preferredTime));

    if (preferredTimeComparison != 0) {
      return preferredTimeComparison;
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
