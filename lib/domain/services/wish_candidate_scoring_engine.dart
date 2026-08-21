import '../entities/facility.dart';
import '../entities/plan_preference.dart';
import '../entities/time_band_wait_profile.dart';
import '../enums/wait_time_band.dart';
import 'dynamic_wait_scoring_service.dart';

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
  const WishCandidateScoringEngine({this.dynamicWaitScoringService = const DynamicWaitScoringService()});

  final DynamicWaitScoringService dynamicWaitScoringService;

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
      final reliableRange = range != null &&
              range.typicalMinutes > 0 &&
              (range.sampleCount == null || range.sampleCount! >= 3)
          ? range
          : null;
      final predictedWait =
          reliableRange?.typicalMinutes ?? facility.waitTime?.minutes ?? 30;
      final waitScore = dynamicWaitScoringService.evaluate(facilityId: facility.id, profiles: waitProfiles, facilityCurrentWaitMinutes: facility.waitTime?.minutes, fallbackMinutes: predictedWait);
      final priority = preference?.priority.value ?? facility.priority.value;
      final totalMinutes = facility.durationMinutes + predictedWait;
      var value = priority * 30.0;
      value -= predictedWait * 0.65;
      value -= facility.durationMinutes * 0.15;
      if (facility.supportsDpa && predictedWait >= 60) value += 12;
      if (totalMinutes > availableMinutes) value -= 1000;

      // First Move は待ち時間節約を中心にしつつ、施設そのものの目的地価値も評価する。
      // Priority Pass は評価対象外。DPAのみ現行の代替手段として扱う。
      final baseExperienceValue = switch (priority) {
        >= 5 => 40.0,
        4 => 20.0,
        3 => 10.0,
        2 => 5.0,
        _ => 0.0,
      };
      var firstMove = waitScore.savingMinutes.toDouble();
      firstMove += baseExperienceValue;
      if (facility.isSeasonal) firstMove += 12;
      if (hasHappyEntry && waitScore.savingMinutes > 0) firstMove += 8;
      if (facility.supportsDpa && !waitScore.usedFallback) firstMove -= 12;
      if (preference?.preferredTime.name == 'morning') firstMove += 15;
      final firstReasons = <String>[
        '朝一予測${waitScore.openingMinutes}分',
        '通常時間帯代表${waitScore.normalMinutes}分',
        '朝一で約${waitScore.savingMinutes}分節約見込み',
        '待ち時間データ: ${waitScore.source}',
        'サンプル数${waitScore.sampleCount}件',
        '信頼度${waitScore.confidence.name}',
        '施設基礎価値${baseExperienceValue.round()}点',
        if (facility.isSeasonal) '期間限定施設 +12',
        if (hasHappyEntry && waitScore.savingMinutes > 0)
          'ハッピーエントリー効果を考慮',
        if (facility.supportsDpa && !waitScore.usedFallback)
          'DPA代替可能性を減点',
        if (facility.supportsDpa && waitScore.usedFallback)
          '待ち時間DB不足のためDPA減点は保留',
        'Priority Passは評価対象外',
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
