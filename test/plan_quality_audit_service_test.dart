import 'package:flutter_test/flutter_test.dart';
import 'package:disney_planner/domain/entities/day_schedule.dart';
import 'package:disney_planner/domain/entities/schedule_item.dart';
import 'package:disney_planner/domain/enums/schedule_item_type.dart';
import 'package:disney_planner/domain/services/plan_quality_audit_service.dart';

void main() {
  test('plan quality audit measures wait free time and overlaps', () {
    final schedule = DaySchedule(
      id: 'test',
      parkId: 'tokyo_disneyland',
      createdAt: DateTime(2026, 10, 5),
      items: const [
        ScheduleItem(id: 'a', title: 'A', type: ScheduleItemType.facility, startHour: 9, startMinute: 0, endHour: 10, endMinute: 0, estimatedWaitMinutes: 40),
        ScheduleItem(id: 'free', title: '休憩・自由時間', type: ScheduleItemType.breakTime, startHour: 10, startMinute: 10, endHour: 11, endMinute: 20),
        ScheduleItem(id: 'b', title: 'B', type: ScheduleItemType.facility, startHour: 11, startMinute: 20, endHour: 12, endMinute: 0, estimatedWaitMinutes: 20),
      ],
    );
    final audit = const PlanQualityAuditService().evaluate(schedule);
    expect(audit.totalWaitMinutes, 60);
    expect(audit.totalFreeMinutes, 70);
    expect(audit.largestFreeBlockMinutes, 70);
    expect(audit.overlapCount, 0);
  });
}
