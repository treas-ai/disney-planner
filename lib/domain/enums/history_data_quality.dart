enum HistoryDataQuality {
  high(label: '高'),
  medium(label: '中'),
  low(label: '低');

  const HistoryDataQuality({required this.label});

  final String label;
}
