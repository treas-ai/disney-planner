import '../enums/schedule_validation_severity.dart';

class ScheduleValidationIssue {
  const ScheduleValidationIssue({
    required this.code,
    required this.message,
    required this.severity,
  });

  final String code;
  final String message;
  final ScheduleValidationSeverity severity;
}
