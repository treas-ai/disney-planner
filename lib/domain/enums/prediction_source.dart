enum PredictionSource {
  currentOnly(label: '現在値'),
  historyOnly(label: '履歴'),
  waitProfile(label: '収集実績'),
  currentAndWaitProfile(label: '現在値＋収集実績'),
  planningFallback(label: '計画値'),
  hybrid(label: '現在値＋履歴');

  const PredictionSource({required this.label});

  final String label;
}
