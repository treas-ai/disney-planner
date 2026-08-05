enum FreeDrinkFulfillmentType {
  pickup('受け取り口で受け取る'),
  counter('通常カウンターで受け取る'),
  seated('店内利用・着席が必要');

  const FreeDrinkFulfillmentType(this.label);

  final String label;

  static FreeDrinkFulfillmentType fromName(String? value) {
    return FreeDrinkFulfillmentType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => FreeDrinkFulfillmentType.pickup,
    );
  }
}
