import 'package:disney_planner/domain/entities/activity_history_record.dart';
import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/live_wait_time.dart';
import 'package:disney_planner/domain/entities/time_band_wait_profile.dart';
import 'package:disney_planner/domain/entities/wait_time_prediction.dart';
import 'package:disney_planner/domain/entities/wait_time_range.dart';
import 'package:disney_planner/domain/enums/activity_history_type.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/prediction_confidence.dart';
import 'package:disney_planner/domain/enums/prediction_source.dart';
import 'package:disney_planner/domain/enums/wait_time_band.dart';
import 'package:disney_planner/domain/repositories/history_repository.dart';
import 'package:disney_planner/domain/services/rule_based_wait_time_prediction_engine.dart';
import 'package:disney_planner/domain/services/wait_time_prediction_engine.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:disney_planner/features/live/live_models.dart';
import 'package:disney_planner/features/live/live_prediction_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyHistoryRepository implements HistoryRepository {
  const _EmptyHistoryRepository();

  @override
  Future<void> clearAll() async {}
  @override
  Future<List<ActivityHistoryRecord>> loadAll() async => const [];
  @override
  Future<List<ActivityHistoryRecord>> loadByType(ActivityHistoryType type) async => const [];
  @override
  Future<List<ActivityHistoryRecord>> loadForFacility(String facilityId) async => const [];
  @override
  Future<List<ActivityHistoryRecord>> loadForPark(String parkId) async => const [];
  @override
  Future<void> remove(String recordId) async {}
  @override
  Future<void> save(ActivityHistoryRecord record) async {}
  @override
  Future<void> saveAll(Iterable<ActivityHistoryRecord> records) async {}
}

class _RecordingPredictionEngine implements WaitTimePredictionEngine {
  DateTime? lastTargetTime;
  int? lastCurrentWaitMinutes;
  TimeBandWaitProfile? lastProfile;

  @override
  Future<WaitTimePrediction> predict({
    required String parkId,
    required String facilityId,
    required DateTime targetTime,
    int? currentWaitMinutes,
    DateTime? currentWaitUpdatedAt,
    DateTime? referenceTime,
    TimeBandWaitProfile? waitProfile,
    int? planningFallbackMinutes,
    String? planningFallbackReason,
  }) async {
    lastTargetTime = targetTime;
    lastCurrentWaitMinutes = currentWaitMinutes;
    lastProfile = waitProfile;
    return WaitTimePrediction(
      parkId: parkId,
      facilityId: facilityId,
      targetTime: targetTime,
      generatedAt: DateTime(2026, 9, 10),
      predictedMinutes: 50,
      lowerBoundMinutes: 40,
      upperBoundMinutes: 60,
      confidence: PredictionConfidence.medium,
      source: PredictionSource.waitProfile,
      reasons: const ['test'],
      sampleCount: 30,
    );
  }
}

TimeBandWaitProfile _profile() {
  return TimeBandWaitProfile(
    facilityId: 'baymax',
    parkId: 'tokyo_disneyland',
    ranges: {
      WaitTimeBand.afterLunch: const WaitTimeRange(
        minMinutes: 20,
        typicalMinutes: 50,
        maxMinutes: 80,
        sampleCount: 120,
      ),
    },
    source: 'Git collected profile',
    calculatedAt: DateTime.utc(2026, 9, 9),
    sampleCount: 120,
  );
}

Facility _facility() {
  return const Facility(
    id: 'baymax',
    parkId: 'tokyo_disneyland',
    areaId: 'tomorrowland',
    name: 'ベイマックスのハッピーライド',
    category: FacilityCategory.attraction,
    coordinate: Coordinate(latitude: 0, longitude: 0),
    durationMinutes: 2,
  );
}

void main() {
  test('Git wait profileだけでも予定時刻の待ち時間を予測できる', () async {
    final engine = RuleBasedWaitTimePredictionEngine(
      const _EmptyHistoryRepository(),
    );
    final prediction = await engine.predict(
      parkId: 'tokyo_disneyland',
      facilityId: 'baymax',
      targetTime: DateTime(2026, 10, 5, 13),
      referenceTime: DateTime(2026, 10, 5, 9),
      waitProfile: _profile(),
    );

    expect(prediction.predictedMinutes, 50);
    expect(prediction.lowerBoundMinutes, 40);
    expect(prediction.upperBoundMinutes, 60);
    expect(prediction.source, PredictionSource.waitProfile);
    expect(prediction.confidence, PredictionConfidence.high);
    expect(prediction.rangeLabel, '40〜60分');
    expect(prediction.reasons.join(' '), contains('Gitで収集した待ち時間実績'));
  });

  test('来園日前は現在値を使わず来園日の予定時刻を予測対象にする', () async {
    final recordingEngine = _RecordingPredictionEngine();
    final controller = LivePredictionController(engine: recordingEngine);
    final plannedTarget = DateTime(2026, 10, 5, 10, 20);

    await controller.load(
      parkId: 'tokyo_disneyland',
      facilities: [_facility()],
      referenceTime: DateTime(2026, 10, 5, 9, 10),
      useVisitDayTargets: false,
      waitProfiles: [_profile()],
      currentWaitTimeFor: (_) => LiveWaitTime(
        facilityId: 'baymax',
        parkId: 'tokyo_disneyland',
        waitMinutes: 90,
        updatedAt: DateTime(2026, 9, 10, 14),
      ),
      plannedTargetTimeFor: (_) => plannedTarget,
    );

    expect(recordingEngine.lastTargetTime, plannedTarget);
    expect(recordingEngine.lastCurrentWaitMinutes, isNull);
    expect(recordingEngine.lastProfile?.facilityId, 'baymax');
    expect(controller.predictionsForFacility('baymax'), hasLength(1));
  });

  test('来園日判定は日付だけで比較し未来日の時刻進行を開始しない', () {
    final now = DateTime(2026, 9, 10, 23, 59);
    expect(
      resolveLiveVisitPhase(now: now, visitDate: DateTime(2026, 10, 5)),
      LiveVisitPhase.preVisit,
    );
    expect(
      resolveLiveVisitPhase(now: now, visitDate: DateTime(2026, 9, 10, 8)),
      LiveVisitPhase.visitDay,
    );
    expect(
      resolveLiveVisitPhase(now: now, visitDate: DateTime(2026, 9, 9)),
      LiveVisitPhase.postVisit,
    );
  });

  test('グリーティングは実測profileが無ければ計画値を予測表示に使う', () async {
    final engine = RuleBasedWaitTimePredictionEngine(
      const _EmptyHistoryRepository(),
    );
    final prediction = await engine.predict(
      parkId: 'tokyo_disneyland',
      facilityId: 'mickey_greeting',
      targetTime: DateTime(2026, 11, 18, 9, 15),
      referenceTime: DateTime(2026, 11, 18, 9),
      planningFallbackMinutes: 240,
      planningFallbackReason: 'キャラクター記念日のDisney Planner計画値',
    );

    expect(prediction.predictedMinutes, 240);
    expect(prediction.source, PredictionSource.planningFallback);
    expect(prediction.confidence, PredictionConfidence.low);
    expect(prediction.reasons.join(' '), contains('実測待ち時間ではありません'));
  });

}
