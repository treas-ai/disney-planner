enum WishItemCategory {
  attraction('アトラクション'),
  entertainment('ショー・パレード'),
  greeting('キャラクターグリーティング'),
  specialDrink('スペシャルドリンク'),
  cafeDrink('コーヒー系ドリンク'),
  juice('ジュース'),
  soup('スープ'),
  drinkJelly('ドリンクジュレ'),
  food('フード'),
  dessert('デザート'),
  snack('スナック'),
  restaurant('パーク内レストラン'),
  hotelRestaurant('ホテルレストラン'),
  goods('グッズ'),
  souvenir('スーベニア'),
  photo('フォトスポット'),
  other('その他');

  const WishItemCategory(this.label);

  final String label;

  bool get isFreeDrinkMenuCategory {
    return switch (this) {
      WishItemCategory.specialDrink ||
      WishItemCategory.cafeDrink ||
      WishItemCategory.juice ||
      WishItemCategory.soup ||
      WishItemCategory.drinkJelly => true,
      _ => false,
    };
  }
}
