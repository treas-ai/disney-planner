import 'package:disney_planner/domain/entities/assistant_context.dart';
import 'package:disney_planner/domain/entities/day_schedule.dart';
import 'package:disney_planner/domain/entities/schedule_item.dart';
import 'package:disney_planner/domain/enums/recommendation_priority.dart';
import 'package:disney_planner/domain/enums/schedule_item_type.dart';
import 'package:disney_planner/domain/services/assistant_intelligence_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = AssistantIntelligenceEngine();

  test('予定開始が近い場合は至急判定になる', () {
    final context = AssistantContext(
      now: DateTime(2026, 8, 4, 10),
      schedule: DaySchedule(
        id: 'test',
        parkId: 'tds',
        items: [
          ScheduleItem(
            id: 'next',
            title: '次の予定',
            type: ScheduleItemType.facility,
            startHour: 10,
            startMinute: 5,
            endHour: 10,
            endMinute: 30,
          ),
        ],
        createdAt: DateTime(2026, 8, 4),
      ),
      facilities: const [],
    );

    final insight = engine.assessNextAction(
      context: context,
      next: context.schedule!.items.first,
    );

    expect(insight.priority, RecommendationPriority.urgent);
    expect(insight.score, greaterThanOrEqualTo(80));
  });
}
