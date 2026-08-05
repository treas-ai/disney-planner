import '../enums/dpa_strategy_type.dart';

class DpaStrategy {
  const DpaStrategy({required this.type, required this.maxUses})
    : assert(maxUses == null || maxUses >= 0);

  const DpaStrategy.disabled() : type = DpaStrategyType.disabled, maxUses = 0;

  factory DpaStrategy.fromJson(Map<String, dynamic> json) {
    return DpaStrategy(
      type: DpaStrategyType.fromName(json['type'] as String?),
      maxUses: json['maxUses'] as int?,
    );
  }

  final DpaStrategyType type;
  final int? maxUses;

  bool get isEnabled =>
      type != DpaStrategyType.disabled && (maxUses == null || maxUses! > 0);

  Map<String, dynamic> toJson() {
    return {'type': type.name, 'maxUses': maxUses};
  }
}
