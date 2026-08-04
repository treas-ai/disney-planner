enum ScheduleValidationSeverity {
  information('確認'),
  warning('注意'),
  error('要修正');

  const ScheduleValidationSeverity(this.label);

  final String label;
}
