import 'wish_item.dart';

class WishEventPack {
  const WishEventPack({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.updatedAt,
    required this.items,
    required this.sourceUrls,
    this.isRemote = false,
  });

  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime updatedAt;
  final List<WishItem> items;
  final List<String> sourceUrls;
  final bool isRemote;

  bool isAvailableOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  factory WishEventPack.fromJson(
    Map<String, dynamic> json, {
    bool isRemote = false,
  }) {
    final id = json['id']?.toString() ?? '';
    final items = (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => WishItem.fromJson({
            for (final entry in item.entries) entry.key.toString(): entry.value,
            'eventPackId': id,
          }),
        )
        .toList(growable: false);

    return WishEventPack(
      id: id,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      startDate:
          DateTime.tryParse(json['startDate']?.toString() ?? '') ??
          DateTime(2000),
      endDate:
          DateTime.tryParse(json['endDate']?.toString() ?? '') ??
          DateTime(2100),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime(2000),
      items: items,
      sourceUrls: (json['sourceUrls'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      isRemote: isRemote,
    );
  }
}
