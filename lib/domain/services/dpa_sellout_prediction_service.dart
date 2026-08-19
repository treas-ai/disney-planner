import '../entities/dpa_sellout_profile.dart';

enum DpaSelloutRisk { unknown, low, medium, high, likelySoldOut }

class DpaSelloutPrediction {
  const DpaSelloutPrediction({
    required this.risk,
    required this.minutesUntilAverageSellout,
    required this.profile,
  });

  final DpaSelloutRisk risk;
  final int? minutesUntilAverageSellout;
  final DpaSelloutProfile? profile;
}

class DpaSelloutPredictionService {
  const DpaSelloutPredictionService();

  DpaSelloutPrediction evaluate({
    required String facilityId,
    required int predictedEntryMinuteOfDay,
    required List<DpaSelloutProfile> profiles,
  }) {
    DpaSelloutProfile? profile;
    for (final item in profiles) {
      if (item.facilityId == facilityId) {
        profile = item;
        break;
      }
    }
    final sellout = profile?.averageSelloutMinuteOfDay;
    if (profile == null || sellout == null) {
      return const DpaSelloutPrediction(
        risk: DpaSelloutRisk.unknown,
        minutesUntilAverageSellout: null,
        profile: null,
      );
    }

    final remaining = sellout - predictedEntryMinuteOfDay;
    final risk = remaining <= 0
        ? DpaSelloutRisk.likelySoldOut
        : remaining <= 30
            ? DpaSelloutRisk.high
            : remaining <= 90
                ? DpaSelloutRisk.medium
                : DpaSelloutRisk.low;

    return DpaSelloutPrediction(
      risk: risk,
      minutesUntilAverageSellout: remaining,
      profile: profile,
    );
  }
}
