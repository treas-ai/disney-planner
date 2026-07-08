enum FacilityCategory {
  attraction('アトラクション'),
  show('ショー'),
  restaurant('レストラン'),
  shop('ショップ');

  const FacilityCategory(this.label);

  final String label;
}