import 'package:flutter_test/flutter_test.dart';
import 'package:disney_planner/domain/services/official_dpa_price_catalog.dart';

void main() {
  const catalog = OfficialDpaPriceCatalog();

  test('official DPA snapshot identifies its verification date', () {
    expect(OfficialDpaPriceCatalog.verifiedOn, '2026-09-23');
  });

  test('TDL 2026-09-26 current attraction DPA prices stay date-aware', () {
    final date = DateTime(2026, 9, 26);
    expect(catalog.quote('tdl_new_fantasyland_enchanted_tale_of_beauty_and_the_beast', date)?.pricePerPersonYen, 2500);
    expect(catalog.quote('tdl_tomorrowland_baymax_happy_ride', date)?.pricePerPersonYen, 1500);
    expect(catalog.quote('tdl_critter_country_splash_mountain', date)?.pricePerPersonYen, 1500);
    expect(catalog.quote('tdl_westernland_big_thunder_mountain', date)?.pricePerPersonYen, 1500);
    expect(catalog.quote('tdl_fantasyland_poohs_hunny_hunt', date)?.pricePerPersonYen, 1500);
    expect(catalog.quote('tdl_tomorrowland_monsters_inc_ride_and_go_seek', date)?.pricePerPersonYen, 1000);
    expect(catalog.quote('tdl_fantasyland_haunted_mansion', date)?.pricePerPersonYen, 1000);
  });

  test('date-limited DPA is not silently priced outside its period', () {
    expect(catalog.quote('tdl_fantasyland_haunted_mansion', DateTime(2026, 9, 14)), isNull);
  });
}
