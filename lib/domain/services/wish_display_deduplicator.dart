import '../entities/wish_item.dart';

/// Collapses duplicate records that represent the same user-facing wish.
/// Scheduling data remains untouched; this is discovery/selection UI only.
class WishDisplayDeduplicator {
  const WishDisplayDeduplicator._();

  static List<WishItem> deduplicate(
    Iterable<WishItem> items, {
    Set<String> selectedIds = const {},
  }) {
    final byKey = <String, WishItem>{};
    for (final item in items) {
      final key = logicalKey(item);
      final current = byKey[key];
      if (current == null || _prefer(item, current, selectedIds)) {
        byKey[key] = item;
      }
    }
    return byKey.values.toList(growable: false);
  }

  static String logicalKey(WishItem item) =>
      '${item.parkId}|${item.category.name}|${_normalizeName(item.name)}';

  static bool _prefer(
    WishItem candidate,
    WishItem current,
    Set<String> selectedIds,
  ) {
    final candidateSelected = selectedIds.contains(candidate.id);
    final currentSelected = selectedIds.contains(current.id);
    if (candidateSelected != currentSelected) return candidateSelected;

    final candidateIsPack = candidate.eventPackId != 'facility_master';
    final currentIsPack = current.eventPackId != 'facility_master';
    if (candidateIsPack != currentIsPack) return candidateIsPack;

    final candidateVenueIsSelf = candidate.venueNames.length == 1 &&
        candidate.venueNames.first == candidate.name;
    final currentVenueIsSelf = current.venueNames.length == 1 &&
        current.venueNames.first == current.name;
    if (candidateVenueIsSelf != currentVenueIsSelf) return !candidateVenueIsSelf;

    return false;
  }

  static String _normalizeName(String value) {
    var result = value.toLowerCase().replaceAll('　', ' ');
    const punctuation = <String>[
      ' ', '・', '･', '-', '‐', '‑', '‒', '–', '—', '―', 'ー', '_', '.', '/',
      r'\', ',', ':', '：', ';', '；', '(', ')', '（', '）', '[', ']', '【', '】',
      '「', '」', '『', '』', '“', '”', '"', "'",
    ];
    for (final mark in punctuation) {
      result = result.replaceAll(mark, '');
    }
    return result;
  }
}
