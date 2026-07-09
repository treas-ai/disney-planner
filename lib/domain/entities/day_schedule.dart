import 'schedule_item.dart';

class DaySchedule {
  const DaySchedule({
    required this.id,
    required this.parkId,
    required this.items,
    required this.createdAt,
  });

  factory DaySchedule.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return DaySchedule(
      id: json['id'] as String? ?? '',
      parkId: json['parkId'] as String? ?? '',
      items: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(ScheduleItem.fromJson)
              .toList()
          : [],
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String parkId;
  final List<ScheduleItem> items;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parkId': parkId,
      'items': items.map((item) => item.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}