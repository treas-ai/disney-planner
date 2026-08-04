import '../entities/assistant_context.dart';
import '../entities/assistant_insight.dart';
import '../entities/schedule_item.dart';
import '../enums/facility_operating_status.dart';
import '../enums/intelligence_confidence.dart';
import '../enums/priority_level.dart';
import '../enums/recommendation_priority.dart';
import 'event_impact_engine.dart';

class AssistantIntelligenceEngine {
  const AssistantIntelligenceEngine({
    this.eventImpactEngine = const EventImpactEngine(),
  });

  final EventImpactEngine eventImpactEngine;

  AssistantInsight assessNextAction({
    required AssistantContext context,
    required ScheduleItem? next,
  }) {
    if (next == null) {
      return const AssistantInsight(
        title: '自由時間',
        description: '現在時刻以降の予定がないため、公式アプリの運営状況を確認して自由に行動できます。',
        priority: RecommendationPriority.low,
        confidence: IntelligenceConfidence.high,
        score: 25,
      );
    }

    final nowMinutes = context.now.hour * 60 + context.now.minute;
    final startMinutes = next.startHour * 60 + next.startMinute;
    final minutesUntilStart = startMinutes - nowMinutes;
    final facility = context.facilityById(next.facilityId);
    final warnings = eventImpactEngine.warnings(
      atMinutes: nowMinutes,
      impacts: context.eventImpacts,
    );

    var score = 50;
    var priority = RecommendationPriority.normal;
    var confidence = IntelligenceConfidence.medium;
    final reasons = <String>[];

    if (minutesUntilStart <= 10) {
      score += 35;
      priority = RecommendationPriority.urgent;
      reasons.add('開始まで${minutesUntilStart.clamp(0, 10)}分です。');
    } else if (minutesUntilStart <= 30) {
      score += 20;
      priority = RecommendationPriority.high;
      reasons.add('開始まで$minutesUntilStart分です。');
    } else {
      reasons.add('開始まで$minutesUntilStart分あります。');
    }

    if (facility != null) {
      if (facility.priority == PriorityLevel.high ||
          facility.priority == PriorityLevel.highest) {
        score += 10;
        reasons.add('優先度が高い施設です。');
      }

      if (facility.operatingStatus != FacilityOperatingStatus.operating) {
        score -= 30;
        priority = RecommendationPriority.high;
        reasons.add('施設の営業状態を再確認してください。');
      }

      confidence = IntelligenceConfidence.high;
    }

    if (warnings.isNotEmpty) {
      score += 10;
      if (priority == RecommendationPriority.normal) {
        priority = RecommendationPriority.high;
      }
      reasons.add('イベント影響が登録されています。');
    }

    final normalizedScore = score.clamp(0, 100).toInt();
    return AssistantInsight(
      title: next.title,
      description: reasons.join(' '),
      priority: priority,
      confidence: confidence,
      score: normalizedScore,
    );
  }
}
