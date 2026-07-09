enum ScheduleItemType {
  entry('入園'),
  facility('施設'),
  lunch('昼食'),
  dinner('夕食'),
  breakTime('休憩'),
  exit('退園');

  const ScheduleItemType(this.label);

  final String label;
}