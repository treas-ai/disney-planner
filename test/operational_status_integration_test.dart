import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/facility_operating_status.dart';
import 'package:disney_planner/domain/services/schedule_engine.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:disney_planner/domain/value_objects/operating_hours.dart';
import 'package:flutter_test/flutter_test.dart';

Facility _facility({
  required String id,
  required String name,
  FacilityCategory category = FacilityCategory.attraction,
  FacilityOperatingStatus operatingStatus = FacilityOperatingStatus.operating,
  DateTime? closureStartDate,
  DateTime? closureEndDate,
  Map<String, List<OperatingHours>> operatingHoursByDate =
      const <String, List<OperatingHours>>{},
}) {
  return Facility(
    id: id,
    parkId: 'tokyo_disneyland',
    areaId: 'tdl_adventureland',
    name: name,
    category: category,
    coordinate: const Coordinate(latitude: 0, longitude: 0),
    durationMinutes: 10,
    operatingStatus: operatingStatus,
    closureStartDate: closureStartDate,
    closureEndDate: closureEndDate,
    operatingHoursByDate: operatingHoursByDate,
  );
}

void main() {
  test('scheduled closure is unavailable only inside the closure period', () {
    final facility = _facility(
      id: 'scheduled',
      name: '期間休止施設',
      operatingStatus: FacilityOperatingStatus.scheduledClosure,
      closureStartDate: DateTime(2026, 8, 12),
      closureEndDate: DateTime(2026, 8, 26),
    );

    expect(facility.canAddToPlanAt(DateTime(2026, 8, 11)), isTrue);
    expect(facility.canAddToPlanAt(DateTime(2026, 8, 12)), isFalse);
    expect(facility.canAddToPlanAt(DateTime(2026, 8, 26)), isFalse);
    expect(facility.canAddToPlanAt(DateTime(2026, 8, 27)), isTrue);
  });


  test('temporary closure reopens after its end date', () {
    final facility = _facility(
      id: 'temporary',
      name: '一時休止施設',
      operatingStatus: FacilityOperatingStatus.temporarilyClosed,
      closureStartDate: DateTime(2026, 7, 28),
      closureEndDate: DateTime(2026, 8, 10),
    );

    expect(facility.canAddToPlanAt(DateTime(2026, 8, 10)), isFalse);
    expect(facility.canAddToPlanAt(DateTime(2026, 8, 11)), isTrue);
  });

  test('indefinite long-term closure can never enter the plan', () {
    final facility = _facility(
      id: 'swiss',
      name: 'スイスファミリー・ツリーハウス',
      operatingStatus: FacilityOperatingStatus.longTermClosed,
      closureStartDate: DateTime(2022, 4, 1),
    );

    expect(facility.canAddToPlanAt(DateTime(2026, 8, 12)), isFalse);
  });

  test('dated plan excludes closed attraction before scheduling', () {
    final closed = _facility(
      id: 'closed',
      name: '休止中アトラクション',
      operatingStatus: FacilityOperatingStatus.longTermClosed,
      closureStartDate: DateTime(2022, 4, 1),
    );
    final open = _facility(id: 'open', name: '営業中アトラクション');

    final settings = TripSettings.initial().copyWith(
      parkId: 'tokyo_disneyland',
      visitDateIso: '2026-08-12T00:00:00.000',
      wantsBreakfast: false,
      wantsLunch: false,
      wantsDinner: false,
    );

    final schedule = const ScheduleEngine().generate(
      settings: settings,
      facilities: [closed, open],
      preferences: [
        PlanPreference.initial(facilityId: closed.id),
        PlanPreference.initial(facilityId: open.id),
      ],
    );

    expect(
      schedule.items.any((item) => item.facilityId == closed.id),
      isFalse,
    );
    expect(
      schedule.items.any((item) => item.facilityId == open.id),
      isTrue,
    );
  });

  test('unknown restaurant or shop hours do not mean closed', () {
    final restaurant = _facility(
      id: 'unknown_restaurant',
      name: '営業時間未確認レストラン',
      category: FacilityCategory.restaurant,
    );
    final shop = _facility(
      id: 'unknown_shop',
      name: '営業時間未確認ショップ',
      category: FacilityCategory.shop,
    );

    final settings = TripSettings.initial().copyWith(
      parkId: 'tokyo_disneyland',
      visitDateIso: '2026-08-12T00:00:00.000',
      wantsBreakfast: false,
      wantsLunch: false,
      wantsDinner: false,
    );

    final schedule = const ScheduleEngine().generate(
      settings: settings,
      facilities: [restaurant, shop],
      preferences: [
        PlanPreference.initial(facilityId: restaurant.id),
        PlanPreference.initial(facilityId: shop.id),
      ],
    );

    // 営業時間が未確認であることと「休止中」は別。
    // 公式日別営業時間が未登録でも Wish / 候補自体は失わず、
    // ScheduleEngine の安全側フォールバックで扱う。
    expect(
      schedule.items.any((item) => item.facilityId == restaurant.id),
      isTrue,
    );
    expect(
      schedule.items.any((item) => item.facilityId == shop.id),
      isTrue,
    );
  });

  test('daily operating windows preserve split business hours', () {
    final facility = _facility(
      id: 'split_hours',
      name: '分割営業時間レストラン',
      category: FacilityCategory.restaurant,
      operatingHoursByDate: {
        '2026-08-12': [
          OperatingHours(
            open: DateTime(2026, 8, 12, 11),
            close: DateTime(2026, 8, 12, 13),
          ),
          OperatingHours(
            open: DateTime(2026, 8, 12, 14),
            close: DateTime(2026, 8, 12, 20),
          ),
        ],
      },
    );

    final windows = facility.operatingWindowsFor(DateTime(2026, 8, 12));

    expect(windows, hasLength(2));
    expect(windows.first.open.hour, 11);
    expect(windows.first.close.hour, 13);
    expect(windows.last.open.hour, 14);
    expect(windows.last.close.hour, 20);
  });
}
