enum ActivityHistoryType {
  waitTime(label: '待ち時間'),
  movement(label: '移動'),
  facilityUse(label: '施設利用'),
  meal(label: '食事'),
  show(label: 'ショー'),
  shopping(label: '買い物');

  const ActivityHistoryType({required this.label});

  final String label;
}
