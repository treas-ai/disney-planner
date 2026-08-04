enum WishItemCategory {
  attraction('アトラクション'),
  entertainment('ショー・パレード'),
  specialDrink('スペシャルドリンク'),
  cafeDrink('カフェ系ドリンク'),
  juice('ジュース'),
  soup('スープ'),
  drinkJelly('ドリンクジュレ'),
  food('フード'),
  dessert('デザート'),
  snack('スナック'),
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
