enum ScheduleChangeType {
  unchanged('維持'),
  moved('移動'),
  added('追加'),
  removed('除外');

  const ScheduleChangeType(this.label);
  final String label;
}
