enum PredictionConfidence {
  high(label: '高'),
  medium(label: '中'),
  low(label: '低'),
  unavailable(label: '算出不可');

  const PredictionConfidence({required this.label});

  final String label;
}
