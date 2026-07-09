import 'package:flutter/foundation.dart';

import '../../domain/entities/facility.dart';
import '../../domain/entities/plan_candidate.dart';

class PlanBuilderController extends ChangeNotifier {
  final List<PlanCandidate> _candidates = [];

  List<PlanCandidate> get candidates => List.unmodifiable(_candidates);

  int get selectedCount => _candidates.length;

  bool isSelected(String facilityId) {
    return _candidates.any((candidate) => candidate.facilityId == facilityId);
  }

  void addFacility(Facility facility) {
    if (isSelected(facility.id)) {
      return;
    }

    final candidate = PlanCandidate(
      id: 'candidate_${facility.id}_${DateTime.now().millisecondsSinceEpoch}',
      facilityId: facility.id,
      addedAt: DateTime.now(),
    );

    _candidates.add(candidate);
    notifyListeners();
  }

  void removeFacility(String facilityId) {
    _candidates.removeWhere(
      (candidate) => candidate.facilityId == facilityId,
    );

    notifyListeners();
  }

  void clear() {
    _candidates.clear();
    notifyListeners();
  }

  List<Facility> getSelectedFacilities(List<Facility> allFacilities) {
    return allFacilities
        .where((facility) => isSelected(facility.id))
        .toList();
  }
}