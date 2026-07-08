enum PreferredTime {
  morning('午前'),
  afternoon('午後'),
  evening('夕方〜夜'),
  anytime('いつでも');

  const PreferredTime(this.label);

  final String label;
}