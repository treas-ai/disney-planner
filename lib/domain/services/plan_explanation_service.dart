import '../entities/day_schedule.dart';
import '../entities/facility.dart';
import '../entities/plan_explanation.dart';
import '../entities/plan_preference.dart';
import '../entities/trip_settings.dart';
import '../enums/fixed_time_status.dart';
import '../enums/preferred_time.dart';
import '../enums/schedule_item_type.dart';

/// Builds deterministic explanations only from facts already present in the
/// generated plan/settings. It does not infer hidden optimizer motives.
class PlanExplanationService {
  const PlanExplanationService();

  PlanExplanation build({
    required DaySchedule schedule,
    required TripSettings settings,
    required List<Facility> desiredFacilities,
    required List<PlanPreference> preferences,
    required int achievedDesiredCount,
    required int hardAchievedCount,
    required int totalHardDesiredCount,
    required int largestFreeBlockMinutes,
    Map<String, String> optionalRejectionReasons = const <String, String>{},
  }) {
    final preferenceById = <String, PlanPreference>{
      for (final preference in preferences) preference.facilityId: preference,
    };
    final scheduledCounts = <String, int>{};
    for (final item in schedule.items) {
      final id = item.facilityId;
      if (id != null && id.isNotEmpty) {
        scheduledCounts.update(id, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    final explainedItems = schedule.items
        .where((item) => item.type == ScheduleItemType.facility)
        .map((item) {
          final preference = preferenceById[item.facilityId];
          final sourceReason = item.reason?.trim() ?? '';
          final fallbackDetail = preference?.fixedTimeStatus == FixedTimeStatus.confirmed
              ? '取得・予約済みの時刻を固定して配置しています。'
              : preference != null && preference.priority.value > 2
                  ? '優先度の高い「やりたいこと」としてプランに含めています。'
                  : '選択した組み方で成立した予定として配置しています。';
          final detailReason = sourceReason.isNotEmpty ? sourceReason : fallbackDetail;
          final classification = _classifyReason(
            preference: preference,
            sourceReason: sourceReason,
            optimizationMode: settings.scheduleOptimizationMode,
          );
          return PlanExplanationItem(
            scheduleItemId: item.id,
            title: item.title,
            timeRange: item.timeRangeLabel,
            reason: classification.shortReason,
            detailReason: detailReason,
            category: classification.category,
            evidence: classification.evidence,
          );
        })
        .toList(growable: false);

    final requestedCounts = <String, int>{};
    final facilityById = <String, Facility>{};
    for (final facility in desiredFacilities) {
      requestedCounts.update(facility.id, (value) => value + 1, ifAbsent: () => 1);
      facilityById[facility.id] = facility;
    }
    final unmet = <UnmetWishExplanation>[];
    for (final entry in requestedCounts.entries) {
      final scheduled = scheduledCounts[entry.key] ?? 0;
      if (scheduled >= entry.value) continue;
      final preference = preferenceById[entry.key];
      final knownReason = optionalRejectionReasons[entry.key]?.trim() ?? '';
      final detailReason = knownReason.isNotEmpty
          ? knownReason
          : preference != null && preference.priority.value <= 2
              ? '「できれば」の希望です。現在の固定予定・移動・待ち時間を含む一日最適化では未採用です。'
              : '現在の固定予定・移動・待ち時間を含む一日最適化では、希望回数すべてを配置できませんでした。';
      final missing = entry.value - scheduled;
      final shortReason = preference != null && preference.priority.value <= 2
          ? '今回は「できれば」の希望を$missing回分見送り'
          : '時間条件の中で$missing回分を追加できず';
      unmet.add(UnmetWishExplanation(
        facilityId: entry.key,
        title: facilityById[entry.key]?.name ?? entry.key,
        requestedCount: entry.value,
        scheduledCount: scheduled,
        reason: shortReason,
        detailReason: detailReason,
      ));
    }

    final modeSummary = switch (settings.scheduleOptimizationMode) {
      ScheduleOptimizationMode.balanced => 'バランス重視：待ち時間・移動・自由時間のバランスを見て組んでいます。',
      ScheduleOptimizationMode.minimumWait => '待ち時間重視：希望の達成を守りながら、待ち時間を抑える組み方です。',
      ScheduleOptimizationMode.minimumWalking => '移動少なめ：希望の達成を守りながら、エリア移動を抑える組み方です。',
      ScheduleOptimizationMode.compactSchedule => 'まとまった自由時間：短い空白を減らし、まとまった自由時間を残す組み方です。',
    };
    final hardSummary = totalHardDesiredCount == 0
        ? ''
        : '★$hardAchievedCount/$totalHardDesiredCountを維持し、';
    final freeSummary = largestFreeBlockMinutes > 0
        ? '最大$largestFreeBlockMinutes分のまとまった自由時間を確保しています。'
        : '現在はまとまった自由時間を確保していません。';

    return PlanExplanation(
      modeSummary: modeSummary,
      featureSummary: '希望$achievedDesiredCount/${desiredFacilities.length}、$hardSummary$freeSummary',
      items: explainedItems,
      unmetWishes: unmet,
    );
  }
  _ReasonClassification _classifyReason({
    required PlanPreference? preference,
    required String sourceReason,
    required ScheduleOptimizationMode optimizationMode,
  }) {
    final normalized = sourceReason.replaceAll(' ', '');
    if (preference?.fixedTimeStatus == FixedTimeStatus.confirmed ||
        normalized.contains('固定条件') ||
        normalized.contains('固定予定') ||
        normalized.contains('公演時刻')) {
      return _ReasonClassification(
        category: PlanExplanationReasonCategory.fixedTime,
        shortReason: '時刻を動かさない予定として、この時間を維持',
        evidence: preference?.fixedTimeStatus == FixedTimeStatus.confirmed
            ? '取得・予約済みの固定時刻'
            : 'ScheduleEngineの固定予定・公演時刻理由',
      );
    }
    if (preference != null && preference.preferredTime != PreferredTime.anytime) {
      return _ReasonClassification(
        category: PlanExplanationReasonCategory.preferredTime,
        shortReason: '${preference.preferredTime.label}の希望時間帯に合わせて配置',
        evidence: '希望時間帯: ${preference.preferredTime.label}',
      );
    }

    if (optimizationMode == ScheduleOptimizationMode.compactSchedule &&
        (normalized.contains('空き時間') || normalized.contains('空き枠') || normalized.contains('自由時間'))) {
      return const _ReasonClassification(
        category: PlanExplanationReasonCategory.freeTime,
        shortReason: 'まとまった自由時間を残せる位置に配置',
        evidence: '自由時間重視モード + ScheduleEngineの空き時間理由',
      );
    }
    if (normalized.contains('待ち時間テーブル') ||
        normalized.contains('待ち時間を') ||
        normalized.contains('待機時間')) {
      return const _ReasonClassification(
        category: PlanExplanationReasonCategory.waitTime,
        shortReason: '待ち時間を比較した結果、この時間に配置',
        evidence: 'ScheduleEngineの待ち時間比較理由',
      );
    }
    if (normalized.contains('移動') || normalized.contains('エリア')) {
      return const _ReasonClassification(
        category: PlanExplanationReasonCategory.movement,
        shortReason: '移動を含めて成立する時間に配置',
        evidence: 'ScheduleEngineの移動・エリア理由',
      );
    }
    if (preference != null && preference.priority.value > 2) {
      return const _ReasonClassification(
        category: PlanExplanationReasonCategory.priority,
        shortReason: '優先したい希望としてプランに採用',
        evidence: '希望優先度が通常より高い',
      );
    }
    if (preference != null &&
        (preference.hasReservationTime ||
            preference.hasScheduledAccessTime ||
            preference.hasPreferredPerformanceTime)) {
      return const _ReasonClassification(
        category: PlanExplanationReasonCategory.access,
        shortReason: '指定した利用条件に合わせて配置',
        evidence: '利用・予約・公演時刻の指定あり',
      );
    }
    return const _ReasonClassification(
      category: PlanExplanationReasonCategory.scheduledWish,
      shortReason: 'やりたいこととしてプランに採用',
      evidence: '希望リストにあり、生成プランへ採用済み',
    );
  }

}


class _ReasonClassification {
  const _ReasonClassification({
    required this.category,
    required this.shortReason,
    required this.evidence,
  });

  final PlanExplanationReasonCategory category;
  final String shortReason;
  final String evidence;
}
