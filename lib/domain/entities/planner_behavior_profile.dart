class PlannerBehaviorProfile {
  const PlannerBehaviorProfile({
    this.wishPriorityWeight = 1.0,
    this.waitValueWeight = 1.0,
    this.routePickupWeight = 1.0,
    this.closingUrgencyWeight = 1.0,
    this.expirationUrgencyWeight = 1.0,
    this.comfortWeight = 1.0,
    this.prefersRelaxedPace = false,
    this.collectNearbyWishesBeforeMovingOn = false,
  });

  /// 2026-08-12 / 08-13 の実地ヒアリングから得た行動傾向を
  /// 初期値として表現したプロファイル。
  /// AppStateへ固定保存するのではなく、今後ユーザー設定・学習値へ置換できる。
  factory PlannerBehaviorProfile.observedAugust2026Trips() {
    return const PlannerBehaviorProfile(
      wishPriorityWeight: 1.35,
      waitValueWeight: 1.10,
      routePickupWeight: 1.30,
      closingUrgencyWeight: 1.20,
      expirationUrgencyWeight: 1.45,
      comfortWeight: 1.15,
      prefersRelaxedPace: true,
      collectNearbyWishesBeforeMovingOn: true,
    );
  }

  final double wishPriorityWeight;
  final double waitValueWeight;
  final double routePickupWeight;
  final double closingUrgencyWeight;
  final double expirationUrgencyWeight;
  final double comfortWeight;
  final bool prefersRelaxedPace;
  final bool collectNearbyWishesBeforeMovingOn;
}
