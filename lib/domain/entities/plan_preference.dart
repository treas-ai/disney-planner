import '../enums/meal_preference.dart';
import '../enums/preferred_time.dart';
import '../enums/priority_level.dart';
import '../enums/wait_tolerance.dart';

class PlanPreference {
  const PlanPreference({
    required this.id,
    required this.facilityId,
    required this.priority,
    required this.preferredTime,
    required this.waitTolerance,
    required this.mealPreference,
    required this.useDpa,
    required this.usePriorityPass,
    required this.memo,
    required this.createdAt,
    this.useStandbyPass = false,
    this.prioritizeCapsuleToy = false,
  });

  factory PlanPreference.initial({required String facilityId}) {
    return PlanPreference(
      id:
          'preference_'
          '${facilityId}_'
          '${DateTime.now().millisecondsSinceEpoch}',
      facilityId: facilityId,
      priority: PriorityLevel.medium,
      preferredTime: PreferredTime.anytime,
      waitTolerance: WaitTolerance.medium,
      mealPreference: MealPreference.flexible,
      useDpa: false,
      usePriorityPass: false,
      useStandbyPass: false,
      prioritizeCapsuleToy: false,
      memo: '',
      createdAt: DateTime.now(),
    );
  }

  factory PlanPreference.fromJson(Map<String, dynamic> json) {
    return PlanPreference(
      id: json['id'] as String? ?? '',
      facilityId: json['facilityId'] as String? ?? '',
      priority: PriorityLevel.values.firstWhere(
        (priority) => priority.name == json['priority'],
        orElse: () => PriorityLevel.medium,
      ),
      preferredTime: PreferredTime.values.firstWhere(
        (time) => time.name == json['preferredTime'],
        orElse: () => PreferredTime.anytime,
      ),
      waitTolerance: WaitTolerance.values.firstWhere(
        (tolerance) => tolerance.name == json['waitTolerance'],
        orElse: () => WaitTolerance.medium,
      ),
      mealPreference: MealPreference.values.firstWhere(
        (preference) => preference.name == json['mealPreference'],
        orElse: () => MealPreference.flexible,
      ),
      useDpa: json['useDpa'] as bool? ?? false,
      usePriorityPass: json['usePriorityPass'] as bool? ?? false,
      useStandbyPass: json['useStandbyPass'] as bool? ?? false,
      prioritizeCapsuleToy: json['prioritizeCapsuleToy'] as bool? ?? false,
      memo: json['memo'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String facilityId;

  final PriorityLevel priority;
  final PreferredTime preferredTime;
  final WaitTolerance waitTolerance;
  final MealPreference mealPreference;

  final bool useDpa;
  final bool usePriorityPass;
  final bool useStandbyPass;

  final bool prioritizeCapsuleToy;

  final String memo;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'facilityId': facilityId,
      'priority': priority.name,
      'preferredTime': preferredTime.name,
      'waitTolerance': waitTolerance.name,
      'mealPreference': mealPreference.name,
      'useDpa': useDpa,
      'usePriorityPass': usePriorityPass,
      'useStandbyPass': useStandbyPass,
      'prioritizeCapsuleToy': prioritizeCapsuleToy,
      'memo': memo,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  PlanPreference copyWith({
    String? id,
    String? facilityId,
    PriorityLevel? priority,
    PreferredTime? preferredTime,
    WaitTolerance? waitTolerance,
    MealPreference? mealPreference,
    bool? useDpa,
    bool? usePriorityPass,
    bool? useStandbyPass,
    bool? prioritizeCapsuleToy,
    String? memo,
    DateTime? createdAt,
  }) {
    return PlanPreference(
      id: id ?? this.id,
      facilityId: facilityId ?? this.facilityId,
      priority: priority ?? this.priority,
      preferredTime: preferredTime ?? this.preferredTime,
      waitTolerance: waitTolerance ?? this.waitTolerance,
      mealPreference: mealPreference ?? this.mealPreference,
      useDpa: useDpa ?? this.useDpa,
      usePriorityPass: usePriorityPass ?? this.usePriorityPass,
      useStandbyPass: useStandbyPass ?? this.useStandbyPass,
      prioritizeCapsuleToy: prioritizeCapsuleToy ?? this.prioritizeCapsuleToy,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
