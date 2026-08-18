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
    this.firstMoveScore,
    this.firstMoveReasons = const [],
  });

  final Facility facility;
  final double score;
  final int predictedWaitMinutes;
  final List<String> reasons;
  /// 入園直後の「まずここへ行く」判断専用スコア。距離は評価しない。
  final double? firstMoveScore;
  final List<String> firstMoveReasons;
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
    bool hasHappyEntry = false,
  }) {
    final preferenceById = {for (final item in preferences) item.facilityId: item};
    final profileById = {for (final item in waitProfiles) item.facilityId: item};
    final date = targetDate ?? DateTime.now();
    final scored = facilities
        .where((facility) => facility.canAddToPlanAt(date))
        .map((facility) {
      final preference = preferenceById[facility.id];
      final profile = profileById[facility.id];
      final range = profile?.rangeFor(targetBand);
      final predictedWait = range?.typicalMinutes ?? facility.waitTime?.minutes ?? 30;
      final openingWait = profile?.rangeFor(WaitTimeBand.afterOpening)?.typicalMinutes ?? predictedWait;
      final laterWait = profile?.rangeFor(WaitTimeBand.beforeLunch)?.typicalMinutes ?? predictedWait;
      final deferLoss = (laterWait - openingWait).clamp(0, 240);
      final priority = preference?.priority.value ?? facility.priority.value;
      final totalMinutes = facility.durationMinutes + predictedWait;
      var value = priority * 30.0;
      value -= predictedWait * 0.65;
      value -= facility.durationMinutes * 0.15;
      if (facility.supportsDpa && predictedWait >= 60) value += 12;
      if (totalMinutes > availableMinutes) value -= 1000;

      // 朝一は「入口から近い」ではなく、希望度と後回し損失を中心に評価する。
      // DPA/PP対象だから朝一から外すのではなく、取得手段がある分だけ小さく調整する。
      var firstMove = priority * 24.0 + deferLoss * 1.15 - openingWait * 0.18;
      if (hasHappyEntry) firstMove += 8;
      if (facility.supportsDpa) firstMove -= 4;
      if (facility.supportsPriorityPass) firstMove -= 2;
      if (preference?.preferredTime.name == 'morning') firstMove += 18;

      final firstReasons = <String>[
        '希望度$priority/5',
        '開園直後の予測待ち時間$openingWait分',
        if (deferLoss > 0) '後回しで約$deferLoss分待ち時間増の見込み',
        if (hasHappyEntry) 'ハッピーエントリー効果を考慮',
        if (facility.supportsDpa) 'DPAで代替可能性あり',
        if (facility.supportsPriorityPass) 'PPで代替可能性あり',
        '入口からの距離は朝一スコアに不使用',
      ];
      return WishCandidateScore(
        facility: facility,
        score: value,
        predictedWaitMinutes: predictedWait,
        reasons: [
          '優先度$priority/5',
          '予測待ち時間$predictedWait分',
          if (facility.supportsDpa) 'DPA対象',
        ],
        firstMoveScore: firstMove,
        firstMoveReasons: List.unmodifiable(firstReasons),
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
