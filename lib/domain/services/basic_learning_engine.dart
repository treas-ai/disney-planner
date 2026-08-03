import '../entities/activity_history_record.dart';
import '../entities/learning_data_summary.dart';
import '../enums/activity_history_type.dart';
import 'learning_engine.dart';

class BasicLearningEngine implements LearningEngine {
  const BasicLearningEngine();

  @override
  LearningDataSummary summarize(Iterable<ActivityHistoryRecord> records) {
    final list = records.toList(growable: false);
    if (list.isEmpty) {
      return const LearningDataSummary(
        totalRecordCount: 0,
        trainingEligibleRecordCount: 0,
        waitTimeRecordCount: 0,
        movementRecordCount: 0,
        earliestRecordedAt: null,
        latestRecordedAt: null,
      );
    }

    final sorted = List<ActivityHistoryRecord>.of(list)
      ..sort((left, right) => left.recordedAt.compareTo(right.recordedAt));

    return LearningDataSummary(
      totalRecordCount: list.length,
      trainingEligibleRecordCount: list
          .where((record) => record.isTrainingEligible)
          .length,
      waitTimeRecordCount: list
          .where((record) => record.type == ActivityHistoryType.waitTime)
          .length,
      movementRecordCount: list
          .where((record) => record.type == ActivityHistoryType.movement)
          .length,
      earliestRecordedAt: sorted.first.recordedAt,
      latestRecordedAt: sorted.last.recordedAt,
    );
  }
}
