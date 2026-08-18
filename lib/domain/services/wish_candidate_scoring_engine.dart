import '../entities/facility.dart';
import '../entities/plan_preference.dart';
import '../entities/time_band_wait_profile.dart';
import '../enums/wait_time_band.dart';

class WishCandidateScore {
  const WishCandidateScore({
    required this.facility,
    required this.score,
    required this.predictedWaitMinutes,
    required this.reasons,
  });

  final Facility facility;
  final double score;
  final int predictedWaitMinutes;
  final List<String> reasons;
}

class WishCandidateScoringEngine {
  const WishCandidateScoringEngine();

  List<WishCandidateScore> score({
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
    required List<TimeBandWaitProfile> waitProfiles,
    required int availableMinutes,
    WaitTimeBand targetBand = WaitTimeBand.afterLunch,
    DateTime? targetDate,
  }) {
    final preferenceById = {for (final item in preferences) item.facilityId: item};
    final profileById = {for (final item in waitProfiles) item.facilityId: item};
    final date = targetDate ?? DateTime.now();
    final scored = facilities
        .where((facility) => facility.canAddToPlanAt(date))
        .map((facility) {
      final preference = preferenceById[facility.id];
      final range = profileById[facility.id]?.rangeFor(targetBand);
      final predictedWait = range?.typicalMinutes ?? facility.waitTime?.minutes ?? 30;
      final priority = preference?.priority.value ?? facility.priority.value;
      final totalMinutes = facility.durationMinutes + predictedWait;
      var value = priority * 30.0;
      value -= predictedWait * 0.65;
      value -= facility.durationMinutes * 0.15;
      if (facility.supportsDpa && predictedWait >= 60) value += 12;
      if (totalMinutes > availableMinutes) value -= 1000;
      return WishCandidateScore(
        facility: facility,
        score: value,
        predictedWaitMinutes: predictedWait,
        reasons: [
          '優先度$priority/5',
          '予測待ち時間$predictedWait分',
          if (facility.supportsDpa) 'DPA対象',
        ],
      );
    }).toList(growable: false);
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  List<WishCandidateScore> selectRealisticCount({
    required List<WishCandidateScore> scored,
    required int availableMinutes,
    int movementBufferMinutes = 15,
  }) {
    final selected = <WishCandidateScore>[];
    var used = 0;
    for (final candidate in scored) {
      final needed = candidate.facility.durationMinutes + candidate.predictedWaitMinutes + movementBufferMinutes;
      if (candidate.score < 0 || used + needed > availableMinutes) continue;
      selected.add(candidate);
      used += needed;
    }
    return List.unmodifiable(selected);
  }
}
