class WishItemState {
  const WishItemState({
    required this.itemId,
    this.selected = false,
    this.completed = false,
    this.priority = 3,
  });

  final String itemId;
  final bool selected;
  final bool completed;
  final int priority;

  factory WishItemState.fromJson(Map<String, dynamic> json) {
    return WishItemState(
      itemId: json['itemId']?.toString() ?? '',
      selected: json['selected'] as bool? ?? false,
      completed: json['completed'] as bool? ?? false,
      priority: (json['priority'] as int? ?? 3).clamp(1, 5),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'selected': selected,
      'completed': completed,
      'priority': priority,
    };
  }

  WishItemState copyWith({
    bool? selected,
    bool? completed,
    int? priority,
  }) {
    return WishItemState(
      itemId: itemId,
      selected: selected ?? this.selected,
      completed: completed ?? this.completed,
      priority: (priority ?? this.priority).clamp(1, 5),
    );
  }
}
