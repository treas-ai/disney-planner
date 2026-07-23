enum ShopType {
  none('対象外'),
  general('グッズショップ'),
  capsuleToy('カプセルトイ'),
  apparel('アパレルショップ'),
  confectionery('お菓子ショップ'),
  souvenir('お土産ショップ'),
  specialty('専門ショップ'),
  limited('期間限定ショップ'),
  photoService('フォトサービス');

  const ShopType(this.label);

  final String label;

  bool get isShop {
    return this != ShopType.none;
  }

  bool get isCapsuleToy {
    return this == ShopType.capsuleToy;
  }

  int get defaultDurationMinutes {
    return switch (this) {
      ShopType.none => 60,
      ShopType.capsuleToy => 15,
      ShopType.general ||
      ShopType.apparel ||
      ShopType.confectionery ||
      ShopType.souvenir ||
      ShopType.specialty ||
      ShopType.limited ||
      ShopType.photoService => 25,
    };
  }
}
