enum FixedTimeStatus { none, planned, confirmed }

extension FixedTimeStatusLabel on FixedTimeStatus {
  String get label {
    return switch (this) {
      FixedTimeStatus.none => '指定なし',
      FixedTimeStatus.planned => '取得・予約予定',
      FixedTimeStatus.confirmed => '取得・予約済み',
    };
  }
}
