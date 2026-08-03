import '../entities/activity_history_record.dart';
import '../entities/learning_data_summary.dart';

abstract interface class LearningEngine {
  LearningDataSummary summarize(Iterable<ActivityHistoryRecord> records);
}
