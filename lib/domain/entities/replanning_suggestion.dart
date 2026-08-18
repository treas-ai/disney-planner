import '../enums/replanning_action_type.dart';
import '../enums/replanning_urgency.dart';

class ReplanningSuggestion {
  const ReplanningSuggestion({
    required this.type,
    required this.title,
    required this.reason,
    required this.urgency,
    this.facilityId,
    this.availableMinutes,
  });

  final ReplanningActionType type;
  final String title;
  final String reason;
  final ReplanningUrgency urgency;
  final String? facilityId;
  final int? availableMinutes;
}
