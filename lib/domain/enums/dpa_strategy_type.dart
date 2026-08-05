enum DpaStrategyType {
  attractions('人気アトラクションを効率よく回る'),
  shows('ショーを優先する'),
  balanced('アトラクションとショーにバランスよく使う'),
  highCongestionOnly('本当に混雑している対象だけに使う'),
  disabled('DPAは使わない');

  const DpaStrategyType(this.label);

  final String label;

  static DpaStrategyType fromName(String? value) {
    return DpaStrategyType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => DpaStrategyType.balanced,
    );
  }
}
