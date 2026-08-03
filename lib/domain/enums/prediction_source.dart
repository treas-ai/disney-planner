enum PredictionSource {
  currentOnly(label: '現在値'),
  historyOnly(label: '履歴'),
  hybrid(label: '現在値＋履歴');

  const PredictionSource({required this.label});

  final String label;
}
