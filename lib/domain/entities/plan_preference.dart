import '../enums/facility_access_method.dart';
import '../enums/fixed_time_status.dart';
import '../enums/lottery_fallback_action.dart';
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
    this.accessMethod = FacilityAccessMethod.standby,
    this.preferredPerformanceTime = '',
    this.reservationTime = '',
    this.scheduledAccessTime = '',
    this.fixedTimeStatus = FixedTimeStatus.none,
    this.selectedPerformanceIndex,
    this.lotteryFallbackAction = LotteryFallbackAction.alternativeFacility,
    this.isExcluded = false,
  });

  factory PlanPreference.initial({required String facilityId}) {
    return PlanPreference(
      id: 'preference_${facilityId}_${DateTime.now().millisecondsSinceEpoch}',
      facilityId: facilityId,
      priority: PriorityLevel.medium,
      preferredTime: PreferredTime.anytime,
      waitTolerance: WaitTolerance.medium,
      mealPreference: MealPreference.flexible,
      useDpa: false,
      usePriorityPass: false,
      useStandbyPass: false,
      prioritizeCapsuleToy: false,
      accessMethod: FacilityAccessMethod.standby,
      preferredPerformanceTime: '',
      reservationTime: '',
      scheduledAccessTime: '',
      fixedTimeStatus: FixedTimeStatus.none,
      selectedPerformanceIndex: null,
      lotteryFallbackAction: LotteryFallbackAction.alternativeFacility,
      isExcluded: false,
      memo: '',
      createdAt: DateTime.now(),
    );
  }

  factory PlanPreference.fromJson(Map<String, dynamic> json) {
    final useDpa = json['useDpa'] as bool? ?? false;
    final usePriorityPass = json['usePriorityPass'] as bool? ?? false;
    final useStandbyPass = json['useStandbyPass'] as bool? ?? false;

    final accessMethodName = json['accessMethod'] as String?;

    final accessMethod = accessMethodName == null
        ? _legacyAccessMethod(
            useDpa: useDpa,
            usePriorityPass: usePriorityPass,
            useStandbyPass: useStandbyPass,
          )
        : FacilityAccessMethod.values.firstWhere(
            (method) => method.name == accessMethodName,
            orElse: () => FacilityAccessMethod.standby,
          );

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
      useDpa: accessMethod == FacilityAccessMethod.dpa || useDpa,
      usePriorityPass:
          accessMethod == FacilityAccessMethod.priorityPass || usePriorityPass,
      useStandbyPass:
          accessMethod == FacilityAccessMethod.standbyPass || useStandbyPass,
      prioritizeCapsuleToy: json['prioritizeCapsuleToy'] as bool? ?? false,
      accessMethod: accessMethod,
      preferredPerformanceTime:
          json['preferredPerformanceTime'] as String? ?? '',
      reservationTime: json['reservationTime'] as String? ?? '',
      scheduledAccessTime: json['scheduledAccessTime'] as String? ?? '',
      fixedTimeStatus: _readFixedTimeStatus(json),
      selectedPerformanceIndex: json['selectedPerformanceIndex'] as int?,
      lotteryFallbackAction: LotteryFallbackAction.values.firstWhere(
        (action) => action.name == json['lotteryFallbackAction'],
        orElse: () => LotteryFallbackAction.alternativeFacility,
      ),
      isExcluded: json['isExcluded'] as bool? ?? false,
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

  final FacilityAccessMethod accessMethod;

  /// ショー・パレードの公演開始時刻。HH:mm形式。
  final String preferredPerformanceTime;

  /// レストラン予約・PS・モバイルオーダー受取時刻。HH:mm形式。
  final String reservationTime;

  /// DPA・PP・SP・時間指定アトラクション等の利用時刻。HH:mm形式。
  final String scheduledAccessTime;

  final FixedTimeStatus fixedTimeStatus;

  final int? selectedPerformanceIndex;

  final LotteryFallbackAction lotteryFallbackAction;

  /// 今回のプランでは利用しないという明示的な意思。
  /// 旧保存データとの互換性のため既定値はfalse。
  final bool isExcluded;

  final String memo;
  final DateTime createdAt;

  bool get usesEntryRequest {
    return accessMethod == FacilityAccessMethod.entryRequest;
  }

  bool get hasPreferredPerformanceTime {
    return preferredPerformanceTime.trim().isNotEmpty;
  }

  bool get hasReservationTime {
    return reservationTime.trim().isNotEmpty;
  }

  bool get hasScheduledAccessTime {
    return scheduledAccessTime.trim().isNotEmpty;
  }

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
      'accessMethod': accessMethod.name,
      'preferredPerformanceTime': preferredPerformanceTime,
      'reservationTime': reservationTime,
      'scheduledAccessTime': scheduledAccessTime,
      'fixedTimeStatus': fixedTimeStatus.name,
      'selectedPerformanceIndex': selectedPerformanceIndex,
      'lotteryFallbackAction': lotteryFallbackAction.name,
      'isExcluded': isExcluded,
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
    FacilityAccessMethod? accessMethod,
    String? preferredPerformanceTime,
    String? reservationTime,
    String? scheduledAccessTime,
    FixedTimeStatus? fixedTimeStatus,
    int? selectedPerformanceIndex,
    bool clearSelectedPerformanceIndex = false,
    LotteryFallbackAction? lotteryFallbackAction,
    bool? isExcluded,
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
      accessMethod: accessMethod ?? this.accessMethod,
      preferredPerformanceTime:
          preferredPerformanceTime ?? this.preferredPerformanceTime,
      reservationTime: reservationTime ?? this.reservationTime,
      scheduledAccessTime: scheduledAccessTime ?? this.scheduledAccessTime,
      fixedTimeStatus: fixedTimeStatus ?? this.fixedTimeStatus,
      selectedPerformanceIndex: clearSelectedPerformanceIndex
          ? null
          : selectedPerformanceIndex ?? this.selectedPerformanceIndex,
      lotteryFallbackAction:
          lotteryFallbackAction ?? this.lotteryFallbackAction,
      isExcluded: isExcluded ?? this.isExcluded,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static FixedTimeStatus _readFixedTimeStatus(Map<String, dynamic> json) {
    final raw = json['fixedTimeStatus'] as String?;

    if (raw != null) {
      return FixedTimeStatus.values.firstWhere(
        (value) => value.name == raw,
        orElse: () => FixedTimeStatus.none,
      );
    }

    final hasLegacyTime =
        (json['preferredPerformanceTime'] as String? ?? '').trim().isNotEmpty ||
        (json['reservationTime'] as String? ?? '').trim().isNotEmpty ||
        (json['scheduledAccessTime'] as String? ?? '').trim().isNotEmpty;

    return hasLegacyTime ? FixedTimeStatus.confirmed : FixedTimeStatus.none;
  }

  static FacilityAccessMethod _legacyAccessMethod({
    required bool useDpa,
    required bool usePriorityPass,
    required bool useStandbyPass,
  }) {
    if (useDpa) {
      return FacilityAccessMethod.dpa;
    }

    if (usePriorityPass) {
      return FacilityAccessMethod.priorityPass;
    }

    if (useStandbyPass) {
      return FacilityAccessMethod.standbyPass;
    }

    return FacilityAccessMethod.standby;
  }
}
