enum FacilityAccessMethod {
  standby(label: '通常待機・通常利用', description: '通常列や通常の利用方法で予定を作成します。'),
  dpa(label: 'DPA', description: 'ディズニー・プレミアアクセスを利用します。'),
  priorityPass(label: 'プライオリティパス', description: 'プライオリティパスを利用します。'),
  standbyPass(label: 'スタンバイパス', description: 'スタンバイパスを利用します。'),
  entryRequest(label: 'エントリー受付', description: 'エントリー受付へ申し込む前提で予定を作成します。'),
  reservation(label: '予約', description: '予約済みの時刻を優先して予定を作成します。'),
  freeSeating(label: '自由席・自由鑑賞', description: '自由席や自由鑑賞エリアを利用します。');

  const FacilityAccessMethod({required this.label, required this.description});

  final String label;
  final String description;
}
