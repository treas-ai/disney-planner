enum LiveCrowdLevel {
  veryLow,
  low,
  moderate,
  high,
  veryHigh,
  unknown;

  String get label => switch (this) {
    LiveCrowdLevel.veryLow => 'かなり空いている',
    LiveCrowdLevel.low => '空いている',
    LiveCrowdLevel.moderate => '通常',
    LiveCrowdLevel.high => '混雑',
    LiveCrowdLevel.veryHigh => '非常に混雑',
    LiveCrowdLevel.unknown => '情報なし',
  };

  int get score => switch (this) {
    LiveCrowdLevel.veryLow => 1,
    LiveCrowdLevel.low => 2,
    LiveCrowdLevel.moderate => 3,
    LiveCrowdLevel.high => 4,
    LiveCrowdLevel.veryHigh => 5,
    LiveCrowdLevel.unknown => 0,
  };
}
