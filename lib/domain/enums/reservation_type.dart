enum ReservationType {
  none('なし'),
  standby('通常待ち'),
  priorityPass('Priority Pass'),
  dpa('DPA'),
  mobileOrder('モバイルオーダー'),
  entryRequest('エントリー受付');

  const ReservationType(this.label);

  final String label;
}
