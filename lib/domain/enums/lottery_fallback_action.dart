enum LotteryFallbackAction {
  alternativeFacility(label: '別の施設へ行く', description: '空いた時間へ別の施設を配置します。'),
  freeSeating(label: '自由席・自由鑑賞を利用', description: '利用可能な自由席や自由鑑賞エリアを候補にします。'),
  retryLater(label: '後で再検討', description: '当日の状況を見て別の時間帯で再検討します。'),
  skip(label: '今回は諦める', description: '外れた場合は予定から除外します。');

  const LotteryFallbackAction({required this.label, required this.description});

  final String label;
  final String description;
}
