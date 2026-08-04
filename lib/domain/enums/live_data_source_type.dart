enum LiveDataSourceType {
  mock('サンプルデータ', '動作確認用のサンプル情報'),
  manual('手動入力', '公式アプリを見ながら入力した情報'),
  official('自動取得', '外部データ接続用（接続先は今後設定）');

  const LiveDataSourceType(this.label, this.description);

  final String label;
  final String description;

  static LiveDataSourceType fromName(String? value) {
    return LiveDataSourceType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => LiveDataSourceType.mock,
    );
  }
}
