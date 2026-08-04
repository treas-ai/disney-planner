import 'assistant_insight.dart';

class AssistantResponse {
  const AssistantResponse({
    required this.message,
    required this.reasons,
    this.relatedFacilityId,
    this.insight,
  });

  final String message;
  final List<String> reasons;
  final String? relatedFacilityId;
  final AssistantInsight? insight;
}
