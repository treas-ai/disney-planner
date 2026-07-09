enum WaitTolerance {
  short('短め', 30),
  medium('普通', 60),
  long('長くても可', 120),
  any('気にしない', null);

  const WaitTolerance(
    this.label,
    this.maxMinutes,
  );

  final String label;
  final int? maxMinutes;
}