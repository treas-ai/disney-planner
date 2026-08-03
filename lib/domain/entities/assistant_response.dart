class AssistantResponse {
  const AssistantResponse({
    required this.message,
    required this.reasons,
    this.relatedFacilityId,
  });

  final String message;
  final List<String> reasons;
  final String? relatedFacilityId;
}
