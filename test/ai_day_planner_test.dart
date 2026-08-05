import 'package:flutter_test/flutter_test.dart';
import 'package:disney_planner/ai/planner/ai_day_planner.dart';
import 'package:disney_planner/domain/entities/dpa_strategy.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';

void main() {
  test('空の候補でも入退園を含むスケジュールを生成できる', () {
    const planner = AiDayPlanner();
    final result = planner.generate(
      settings: TripSettings.initial(),
      facilities: const [],
      preferences: const [],
      waitProfiles: const [],
      dpaStrategy: const DpaStrategy.disabled(),
    );

    expect(result.rankedCandidates, isEmpty);
    expect(result.selectedCandidates, isEmpty);
    expect(result.dpaFacilityIds, isEmpty);
    expect(result.schedule.items, isNotEmpty);
  });
}
