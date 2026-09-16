enum TodayAccessStatus {
  acquired,
  won,
  lost,
  unavailable,
  skipped,
}

extension TodayAccessStatusLabel on TodayAccessStatus {
  String get label {
    return switch (this) {
      TodayAccessStatus.acquired => '取得済み',
      TodayAccessStatus.won => '当選',
      TodayAccessStatus.lost => '落選',
      TodayAccessStatus.unavailable => '取得できず',
      TodayAccessStatus.skipped => '利用しない',
    };
  }

  bool get fixesTime =>
      this == TodayAccessStatus.acquired || this == TodayAccessStatus.won;
}
