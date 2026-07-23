enum RestaurantType {
  none('対象外'),
  tableService('テーブルサービス'),
  counterService('カウンターサービス'),
  buffet('ブッフェ'),
  bakeryCafe('ベーカリー・カフェ'),
  snackStand('スナックスタンド'),
  foodWagon('フードワゴン');

  const RestaurantType(this.label);

  final String label;

  bool get isRestaurant {
    return this != RestaurantType.none;
  }

  int get defaultDurationMinutes {
    return switch (this) {
      RestaurantType.none => 60,
      RestaurantType.tableService => 75,
      RestaurantType.counterService => 45,
      RestaurantType.buffet => 90,
      RestaurantType.bakeryCafe => 30,
      RestaurantType.snackStand => 20,
      RestaurantType.foodWagon => 15,
    };
  }
}
