enum FatigueLevel {
  low,
  medium,
  high;

  bool get needsRest => this == FatigueLevel.medium || this == FatigueLevel.high;
}
