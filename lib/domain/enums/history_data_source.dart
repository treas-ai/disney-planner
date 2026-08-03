enum HistoryDataSource {
  manual(label: '手動入力'),
  officialReference(label: '公式情報を参照した入力'),
  system(label: 'アプリ記録'),
  imported(label: 'インポート'),
  predicted(label: 'AI予測');

  const HistoryDataSource({required this.label});

  final String label;
}
