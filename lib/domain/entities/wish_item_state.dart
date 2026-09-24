import '../enums/preferred_time.dart';
import '../enums/wait_tolerance.dart';
import '../enums/wish_importance.dart';

class WishItemState {
  const WishItemState({
    required this.itemId,
    this.selected = false,
    this.completed = false,
    this.priority = 2,
    this.targetCount = 1,
    this.completedCount = 0,
    this.visitCount = 0,
    this.repeatAllowed = false,
    this.preferredTime = PreferredTime.anytime,
    this.waitTolerance = WaitTolerance.any,
  });

  final String itemId;
  final bool selected;
  final bool completed;
  final int priority;

  /// 商品単位Wishの必要回収数。旧データは1として扱う。
  final int targetCount;
  final int completedCount;
  final int visitCount;
  final bool repeatAllowed;
  final PreferredTime preferredTime;
  final WaitTolerance waitTolerance;

  int get remainingCount => (targetCount - completedCount).clamp(0, targetCount);

  /// Beginner-facing three-level wish meaning. Keep legacy numeric priority
  /// for storage compatibility and map it into a stable product concept here.
  WishImportance get importance {
    if (priority >= 5) return WishImportance.mustDo;
    if (priority <= 2) return WishImportance.optional;
    return WishImportance.normal;
  }

  bool get isFulfilled => completed || remainingCount == 0;

  factory WishItemState.fromJson(Map<String, dynamic> json) {
    return WishItemState(
      itemId: json['itemId']?.toString() ?? '',
      selected: json['selected'] as bool? ?? false,
      completed: json['completed'] as bool? ?? false,
      priority: (json['priority'] as int? ?? 3).clamp(1, 5),
      targetCount: (json['targetCount'] as int? ?? 1).clamp(1, 999),
      completedCount: (json['completedCount'] as int? ??
              ((json['completed'] as bool? ?? false) ? 1 : 0))
          .clamp(0, 999),
      visitCount: (json['visitCount'] as int? ?? 0).clamp(0, 999),
      repeatAllowed: json['repeatAllowed'] as bool? ?? false,
      preferredTime: PreferredTime.values.firstWhere(
        (value) => value.name == json['preferredTime'],
        orElse: () => PreferredTime.anytime,
      ),
      waitTolerance: WaitTolerance.values.firstWhere(
        (value) => value.name == json['waitTolerance'],
        orElse: () => WaitTolerance.any,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'selected': selected,
      'completed': completed,
      'priority': priority,
      'targetCount': targetCount,
      'completedCount': completedCount,
      'visitCount': visitCount,
      'repeatAllowed': repeatAllowed,
      'preferredTime': preferredTime.name,
      'waitTolerance': waitTolerance.name,
    };
  }

  WishItemState copyWith({
    bool? selected,
    bool? completed,
    int? priority,
    int? targetCount,
    int? completedCount,
    int? visitCount,
    bool? repeatAllowed,
    PreferredTime? preferredTime,
    WaitTolerance? waitTolerance,
  }) {
    return WishItemState(
      itemId: itemId,
      selected: selected ?? this.selected,
      completed: completed ?? this.completed,
      priority: (priority ?? this.priority).clamp(1, 5),
      targetCount: (targetCount ?? this.targetCount).clamp(1, 999),
      completedCount: (completedCount ?? this.completedCount).clamp(0, 999),
      visitCount: (visitCount ?? this.visitCount).clamp(0, 999),
      repeatAllowed: repeatAllowed ?? this.repeatAllowed,
      preferredTime: preferredTime ?? this.preferredTime,
      waitTolerance: waitTolerance ?? this.waitTolerance,
    );
  }
}
