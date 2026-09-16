enum TodayAccessKind {
  attractionDpa,
  showDpa,
  priorityPass,
  standbyPass,
  entryRequest,
  mobileOrder,
}

extension TodayAccessKindLabel on TodayAccessKind {
  String get label {
    return switch (this) {
      TodayAccessKind.attractionDpa => 'アトラクションDPA',
      TodayAccessKind.showDpa => 'ショーDPA',
      TodayAccessKind.priorityPass => '旧PP（終了）',
      TodayAccessKind.standbyPass => 'スタンバイパス',
      TodayAccessKind.entryRequest => 'エントリー受付',
      TodayAccessKind.mobileOrder => 'モバイルオーダー',
    };
  }
}
