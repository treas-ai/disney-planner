import '../enums/wish_item_category.dart';

class WishItem {
  const WishItem({
    required this.id,
    required this.name,
    required this.category,
    required this.parkId,
    required this.venueFacilityIds,
    required this.venueNames,
    required this.startDate,
    required this.endDate,
    required this.eventPackId,
    this.description,
    this.priceYen,
    this.freeDrinkEligible = false,
    this.freeDrinkEligibilityNote,
    this.mobileOrder = false,
    this.officialUrl,
    this.sourceCheckedAt,
  });

  final String id;
  final String name;
  final WishItemCategory category;
  final String parkId;
  final List<String> venueFacilityIds;
  final List<String> venueNames;
  final DateTime startDate;
  final DateTime endDate;
  final String eventPackId;
  final String? description;
  final int? priceYen;
  final bool freeDrinkEligible;
  final String? freeDrinkEligibilityNote;
  final bool mobileOrder;
  final String? officialUrl;
  final DateTime? sourceCheckedAt;

  bool isAvailableOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  factory WishItem.fromJson(Map<String, dynamic> json) {
    return WishItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: WishItemCategory.values.firstWhere(
        (value) => value.name == json['category'],
        orElse: () => WishItemCategory.other,
      ),
      parkId: json['parkId']?.toString() ?? '',
      venueFacilityIds: (json['venueFacilityIds'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      venueNames: (json['venueNames'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      startDate:
          DateTime.tryParse(json['startDate']?.toString() ?? '') ??
          DateTime(2000),
      endDate:
          DateTime.tryParse(json['endDate']?.toString() ?? '') ??
          DateTime(2100),
      eventPackId: json['eventPackId']?.toString() ?? '',
      description: json['description']?.toString(),
      priceYen: json['priceYen'] as int?,
      freeDrinkEligible: json['freeDrinkEligible'] as bool? ?? false,
      freeDrinkEligibilityNote:
          json['freeDrinkEligibilityNote']?.toString(),
      mobileOrder: json['mobileOrder'] as bool? ?? false,
      officialUrl: json['officialUrl']?.toString(),
      sourceCheckedAt: DateTime.tryParse(
        json['sourceCheckedAt']?.toString() ?? '',
      ),
    );
  }
}
