enum LiveOperationAvailability {
  operating,
  temporarilySuspended,
  systemAdjustment,
  closed,
  unknown;

  String get label => switch (this) {
    LiveOperationAvailability.operating => '運営中',
    LiveOperationAvailability.temporarilySuspended => '一時休止',
    LiveOperationAvailability.systemAdjustment => 'システム調整',
    LiveOperationAvailability.closed => '終了・休止',
    LiveOperationAvailability.unknown => '情報なし',
  };
}
