import 'package:disney_planner/domain/entities/event_impact.dart';
import 'package:disney_planner/domain/enums/event_impact_level.dart';
import 'package:disney_planner/domain/services/event_impact_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = EventImpactEngine();
  const impact = EventImpact(
    id: 'test',
    parkId: 'tokyo_disneysea',
    eventName: 'テストイベント',
    startTime: '19:00',
    endTime: '20:00',
    affectedAreaIds: ['tds_mediterranean_harbor'],
    blockedRouteKeys: ['tds_mediterranean_harbor->tds_american_waterfront'],
    movementPenaltyMinutes: 10,
    level: EventImpactLevel.high,
    enabled: true,
  );

  test('active impact adds movement penalty', () {
    final penalty = engine.movementPenaltyMinutes(
      fromAreaId: 'tds_mediterranean_harbor',
      toAreaId: 'tds_port_discovery',
      atMinutes: 19 * 60 + 30,
      impacts: const [impact],
    );

    expect(penalty, 10);
  });

  test('blocked route is detected', () {
    final blocked = engine.isRouteBlocked(
      fromAreaId: 'tds_american_waterfront',
      toAreaId: 'tds_mediterranean_harbor',
      atMinutes: 19 * 60 + 30,
      impacts: const [impact],
    );

    expect(blocked, isTrue);
  });

  test('impact is inactive outside the configured time', () {
    final penalty = engine.movementPenaltyMinutes(
      fromAreaId: 'tds_mediterranean_harbor',
      toAreaId: 'tds_port_discovery',
      atMinutes: 18 * 60,
      impacts: const [impact],
    );

    expect(penalty, 0);
  });
}
