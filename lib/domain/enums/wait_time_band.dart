enum WaitTimeBand {
  afterOpening('開園直後'),
  beforeLunch('昼前'),
  afterLunch('昼後'),
  aroundShows('ショー前後'),
  beforeDinner('夕食前'),
  afterDinner('夕食後'),
  beforeClosing('閉園間際');

  const WaitTimeBand(this.label);

  final String label;

  static WaitTimeBand fromName(String? value) {
    return WaitTimeBand.values.firstWhere(
      (item) => item.name == value,
      orElse: () => WaitTimeBand.afterOpening,
    );
  }
}
