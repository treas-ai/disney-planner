enum FacilityCategory {
  attraction('アトラクション'),
  show('ショー'),
  parade('パレード'),
  restaurant('レストラン'),
  greeting('グリーティング'),
  shop('ショップ'),
  service('サービス');

  const FacilityCategory(this.label);

  final String label;
}
