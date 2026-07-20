import '../entities/facility.dart';

class PlanGenerator {
  const PlanGenerator();

  List<Facility> sortByPriority(List<Facility> facilities) {
    final sortedFacilities = List<Facility>.from(facilities);

    sortedFacilities.sort(
      (a, b) => b.priority.value.compareTo(a.priority.value),
    );

    return sortedFacilities;
  }
}
