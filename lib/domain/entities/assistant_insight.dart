import '../enums/intelligence_confidence.dart';
import '../enums/recommendation_priority.dart';

class AssistantInsight {
  const AssistantInsight({
    required this.title,
    required this.description,
    required this.priority,
    required this.confidence,
    required this.score,
  });

  final String title;
  final String description;
  final RecommendationPriority priority;
  final IntelligenceConfidence confidence;
  final int score;
}
