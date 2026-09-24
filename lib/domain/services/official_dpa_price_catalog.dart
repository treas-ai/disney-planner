class DpaPriceQuote {
  const DpaPriceQuote({
    required this.facilityId,
    required this.pricePerPersonYen,
    required this.validOnVisitDate,
  });

  final String facilityId;
  final int pricePerPersonYen;
  final bool validOnVisitDate;
}

/// Date-aware snapshot of Tokyo Disney Resort's official DPA attraction prices.
///
/// Keep this catalog explicit and conservative: unknown/out-of-period facilities
/// return null so scenario cost comparison cannot silently invent a price.
class OfficialDpaPriceCatalog {
  const OfficialDpaPriceCatalog();

  /// Official Tokyo Disney Resort DPA price snapshot verified for pre-trip
  /// comparison. Availability/sell-out status is intentionally NOT modeled as
  /// guaranteed here; guests must confirm it in the official app after entry.
  static const String verifiedOn = '2026-09-23';
  static const String officialSourceLabel = 'Tokyo Disney Resort official DPA guide';

  static const Map<String, int> _alwaysAvailable202609 = <String, int>{
    'tdl_new_fantasyland_enchanted_tale_of_beauty_and_the_beast': 2500,
    'tdl_tomorrowland_baymax_happy_ride': 1500,
    'tdl_critter_country_splash_mountain': 1500,
    'tdl_westernland_big_thunder_mountain': 1500,
    'tdl_fantasyland_poohs_hunny_hunt': 1500,
    'tdl_tomorrowland_monsters_inc_ride_and_go_seek': 1000,
    'tds_fs_a_001': 2500,
    'tds_fs_a_002': 2000,
    'tds_fs_a_003': 2000,
    'tds_mh_a_003': 2500,
    'tds_aw_a_003': 2000,
    'tds_aw_a_002': 1500,
    'tds_mi_a_002': 2000,
    'tds_lrd_a_002': 1500,
  };

  DpaPriceQuote? quote(String facilityId, DateTime visitDate) {
    final normalized = DateTime(visitDate.year, visitDate.month, visitDate.day);
    final base = _alwaysAvailable202609[facilityId];
    if (base != null) {
      return DpaPriceQuote(
        facilityId: facilityId,
        pricePerPersonYen: base,
        validOnVisitDate: true,
      );
    }
    if (facilityId == 'tdl_fantasyland_haunted_mansion') {
      final start = DateTime(2026, 9, 15);
      final end = DateTime(2027, 1, 7);
      if (!normalized.isBefore(start) && !normalized.isAfter(end)) {
        return DpaPriceQuote(
          facilityId: facilityId,
          pricePerPersonYen: 1000,
          validOnVisitDate: true,
        );
      }
      return null;
    }
    if (facilityId == 'tds_lrd_a_001') {
      final start = DateTime(2026, 11, 30);
      if (!normalized.isBefore(start)) {
        return DpaPriceQuote(
          facilityId: facilityId,
          pricePerPersonYen: 1500,
          validOnVisitDate: true,
        );
      }
      return null;
    }
    return null;
  }
}
