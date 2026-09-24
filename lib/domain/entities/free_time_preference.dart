import '../enums/preferred_time.dart';

/// User intent to deliberately preserve flexible time in the day.
///
/// This is different from free time that merely remains after scheduling.
/// ScheduleEngine uses this intent to distinguish deliberately preserved
/// flexible time from free time that merely remains after scheduling.
class FreeTimePreference {
  const FreeTimePreference({
    this.enabled = false,
    this.targetMinutes = 0,
    this.minimumBlockMinutes = 60,
    this.preferredTime = PreferredTime.anytime,
  });

  final bool enabled;
  final int targetMinutes;
  final int minimumBlockMinutes;
  final PreferredTime preferredTime;

  factory FreeTimePreference.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FreeTimePreference();
    return FreeTimePreference(
      enabled: json['enabled'] as bool? ?? false,
      targetMinutes: (json['targetMinutes'] as int? ?? 0).clamp(0, 720),
      minimumBlockMinutes:
          (json['minimumBlockMinutes'] as int? ?? 60).clamp(10, 720),
      preferredTime: PreferredTime.values.firstWhere(
        (value) => value.name == json['preferredTime'],
        orElse: () => PreferredTime.anytime,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'targetMinutes': targetMinutes,
        'minimumBlockMinutes': minimumBlockMinutes,
        'preferredTime': preferredTime.name,
      };

  FreeTimePreference copyWith({
    bool? enabled,
    int? targetMinutes,
    int? minimumBlockMinutes,
    PreferredTime? preferredTime,
  }) {
    return FreeTimePreference(
      enabled: enabled ?? this.enabled,
      targetMinutes: (targetMinutes ?? this.targetMinutes).clamp(0, 720),
      minimumBlockMinutes:
          (minimumBlockMinutes ?? this.minimumBlockMinutes).clamp(10, 720),
      preferredTime: preferredTime ?? this.preferredTime,
    );
  }
}
