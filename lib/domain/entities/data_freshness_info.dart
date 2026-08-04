class DataFreshnessInfo {
  const DataFreshnessInfo({
    required this.label,
    required this.updatedAt,
    required this.note,
  });

  final String label;
  final DateTime? updatedAt;
  final String note;

  String get dateLabel {
    final date = updatedAt;
    if (date == null) {
      return '未確認';
    }
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
