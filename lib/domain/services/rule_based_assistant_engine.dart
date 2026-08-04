import '../entities/assistant_context.dart';
import '../entities/assistant_response.dart';
import '../entities/schedule_item.dart';
import 'assistant_engine.dart';
import 'assistant_intelligence_engine.dart';
import 'event_impact_engine.dart';

class RuleBasedAssistantEngine implements AssistantEngine {
  const RuleBasedAssistantEngine({
    this.eventImpactEngine = const EventImpactEngine(),
    this.intelligenceEngine = const AssistantIntelligenceEngine(),
  });

  final EventImpactEngine eventImpactEngine;
  final AssistantIntelligenceEngine intelligenceEngine;

  @override
  Future<AssistantResponse> respond({
    required String question,
    required AssistantContext context,
  }) async {
    final normalized = question.trim().toLowerCase();
    final schedule = context.schedule;

    if (schedule == null || schedule.items.isEmpty) {
      return const AssistantResponse(
        message: 'まだプランがありません。先にプランを生成すると、予定に沿った案内ができます。',
        reasons: ['現在のスケジュールが登録されていません。'],
      );
    }

    final currentMinutes = context.now.hour * 60 + context.now.minute;
    final eventWarnings = eventImpactEngine.warnings(
      atMinutes: currentMinutes,
      impacts: context.eventImpacts,
    );

    final upcoming = _upcomingItems(context);
    final next = upcoming.isEmpty ? null : upcoming.first;

    if (_containsAny(normalized, const ['今どこ', 'どこへ', '次', 'おすすめ'])) {
      return _nextRecommendation(next, context, eventWarnings);
    }

    if (_containsAny(normalized, const ['昼食', '食事', 'ごはん', 'レストラン'])) {
      return _mealRecommendation(upcoming);
    }

    if (_containsAny(normalized, const ['ショー', 'パレード', '公演'])) {
      return _showRecommendation(upcoming);
    }

    if (_containsAny(normalized, const ['混ん', '待ち時間', '並ぶ'])) {
      return const AssistantResponse(
        message:
            '待ち時間は公式アプリで確認し、Disney Plannerへ入力してください。入力後はAI待ち時間予測と再計算機能を利用できます。',
        reasons: ['このコンシェルジュは公式待ち時間を独自に生成しません。', '入力済みデータをプラン判断の補助に利用します。'],
      );
    }

    if (_containsAny(normalized, const ['休憩', '疲れ', 'ゆっくり'])) {
      return AssistantResponse(
        message: next == null
            ? '残り予定がないため、無理をせず休憩を取るのがおすすめです。'
            : '次の予定は${next.startTimeLabel}の「${next.title}」です。開始時刻に余裕があれば、その前に短い休憩を入れてください。',
        reasons: [
          if (next != null) '次の予定開始は${next.startTimeLabel}です。',
          '体調と公式アプリの運営状況を優先してください。',
        ],
        relatedFacilityId: next?.facilityId,
      );
    }

    return _nextRecommendation(next, context, eventWarnings);
  }

  List<ScheduleItem> _upcomingItems(AssistantContext context) {
    final nowMinutes = context.now.hour * 60 + context.now.minute;
    final items = context.schedule!.items
        .where((item) => item.endHour * 60 + item.endMinute >= nowMinutes)
        .toList(growable: false);
    items.sort((left, right) {
      final leftMinutes = left.startHour * 60 + left.startMinute;
      final rightMinutes = right.startHour * 60 + right.startMinute;
      return leftMinutes.compareTo(rightMinutes);
    });
    return items;
  }

  AssistantResponse _nextRecommendation(
    ScheduleItem? next,
    AssistantContext context,
    List<String> eventWarnings,
  ) {
    if (next == null) {
      return const AssistantResponse(
        message: '本日の残り予定はありません。公式アプリで運営状況を確認しながら、自由時間としてお楽しみください。',
        reasons: ['現在時刻以降の予定が見つかりません。'],
      );
    }

    final facility = context.facilityById(next.facilityId);
    final insight = intelligenceEngine.assessNextAction(
      context: context,
      next: next,
    );

    return AssistantResponse(
      message:
          '次は${next.startTimeLabel}から「${next.title}」です。移動と準備の時間を考えて向かいましょう。',
      reasons: [
        '現在のプランで最も近い未完了予定です。',
        ...eventWarnings,
        if (facility != null) '施設エリア：${facility.areaId}',
        if (next.reason != null && next.reason!.trim().isNotEmpty) next.reason!,
      ],
      relatedFacilityId: next.facilityId,
      insight: insight,
    );
  }

  AssistantResponse _mealRecommendation(List<ScheduleItem> upcoming) {
    final meals = upcoming
        .where((item) {
          final title = item.title.toLowerCase();
          return title.contains('昼食') ||
              title.contains('夕食') ||
              title.contains('レストラン') ||
              title.contains('食事');
        })
        .toList(growable: false);

    if (meals.isEmpty) {
      return const AssistantResponse(
        message: '残りのプランに食事予定が見つかりません。固定予定との間隔を確認し、公式アプリで利用可能な店舗を選んでください。',
        reasons: ['現在のスケジュールに未完了の食事予定がありません。'],
      );
    }

    final meal = meals.first;
    return AssistantResponse(
      message:
          '次の食事予定は${meal.startTimeLabel}の「${meal.title}」です。予約・モバイルオーダーの状態は公式アプリでも確認してください。',
      reasons: ['現在のプランに登録された最も近い食事予定です。'],
      relatedFacilityId: meal.facilityId,
    );
  }

  AssistantResponse _showRecommendation(List<ScheduleItem> upcoming) {
    final shows = upcoming
        .where((item) {
          final title = item.title.toLowerCase();
          return title.contains('ショー') ||
              title.contains('パレード') ||
              title.contains('公演');
        })
        .toList(growable: false);

    if (shows.isEmpty) {
      return const AssistantResponse(
        message: '残りのプランにショー・パレード予定はありません。公演情報は公式アプリで確認してください。',
        reasons: ['現在のスケジュールに未完了の公演予定がありません。'],
      );
    }

    final show = shows.first;
    return AssistantResponse(
      message:
          '次の公演予定は${show.startTimeLabel}の「${show.title}」です。入場や鑑賞場所の案内は公式アプリで確認してください。',
      reasons: ['現在のプランに登録された最も近い公演予定です。'],
      relatedFacilityId: show.facilityId,
    );
  }

  bool _containsAny(String source, List<String> keywords) {
    return keywords.any(source.contains);
  }
}
