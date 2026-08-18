import '../entities/facility.dart';
import '../entities/replanning_context.dart';
import '../entities/replanning_suggestion.dart';
import '../entities/live_pass_status.dart';
import '../entities/plan_preference.dart';
import '../enums/facility_access_method.dart';
import '../enums/live_weather_condition.dart';
import '../enums/priority_level.dart';
import '../enums/replanning_action_type.dart';
import '../enums/replanning_urgency.dart';
import 'facility_proximity_service.dart';
import 'route_pickup_service.dart';

class RealtimeReplanningService {
  const RealtimeReplanningService({
    this.routePickupService = const RoutePickupService(),
    this.proximityService = const FacilityProximityService(),
  });

  final RoutePickupService routePickupService;
  final FacilityProximityService proximityService;

  static const int longGapThresholdMinutes = 90;
  static const double walkingMetersPerMinute = 75;

  List<ReplanningSuggestion> assess(ReplanningContext context) {
    final suggestions = <ReplanningSuggestion>[];
    final usableMinutes = context.usableMinutesBeforeFixed;

    if (usableMinutes != null && usableMinutes >= longGapThresholdMinutes) {
      suggestions.add(
        ReplanningSuggestion(
          type: ReplanningActionType.fillLongGap,
          title: '固定予定までの中間プランを作成',
          reason:
              '次の固定予定まで安全バッファを除いて$usableMinutes分あります。'
              '希望・現在地・天候を使って中間プランを組み直せます。',
          urgency: ReplanningUrgency.normal,
          availableMinutes: usableMinutes,
        ),
      );
    }

    final weather = context.weather?.condition;
    if (weather == LiveWeatherCondition.rain ||
        weather == LiveWeatherCondition.heavyRain) {
      suggestions.add(
        ReplanningSuggestion(
          type: ReplanningActionType.preferIndoor,
          title: weather == LiveWeatherCondition.heavyRain
              ? '豪雨向けに屋内中心へ再計画'
              : '雨天向けに屋内候補を優先',
          reason: '屋外Wishを自動削除せず、屋内でWishを同時達成できる候補を優先します。',
          urgency: weather == LiveWeatherCondition.heavyRain
              ? ReplanningUrgency.high
              : ReplanningUrgency.normal,
        ),
      );

      if (context.hotelBreakAvailable &&
          (context.fatigueLevel.needsRest || context.hasBaggage)) {
        suggestions.add(
          ReplanningSuggestion(
            type: ReplanningActionType.hotelBreak,
            title: 'ホテル休憩を候補に追加',
            reason: _hotelBreakReason(context),
            urgency: weather == LiveWeatherCondition.heavyRain
                ? ReplanningUrgency.high
                : ReplanningUrgency.normal,
          ),
        );
      }
    }

    suggestions.addAll(_passFallbackSuggestions(context));
    suggestions.addAll(_routePickupSuggestions(context));

    return List<ReplanningSuggestion>.unmodifiable(suggestions);
  }

  List<Facility> prioritizeForCurrentWeather(ReplanningContext context) {
    final weather = context.weather?.condition;
    if (weather != LiveWeatherCondition.rain &&
        weather != LiveWeatherCondition.heavyRain) {
      return List<Facility>.unmodifiable(context.facilities);
    }

    final indexed = context.facilities.indexed.toList(growable: false);
    indexed.sort((a, b) {
      final aScore = _weatherScore(a.$2, context);
      final bScore = _weatherScore(b.$2, context);
      final scoreCompare = bScore.compareTo(aScore);
      if (scoreCompare != 0) return scoreCompare;
      return a.$1.compareTo(b.$1);
    });
    return List<Facility>.unmodifiable(indexed.map((item) => item.$2));
  }

  List<ReplanningSuggestion> _passFallbackSuggestions(
    ReplanningContext context,
  ) {
    final result = <ReplanningSuggestion>[];
    final preferenceById = {
      for (final preference in context.preferences)
        preference.facilityId: preference,
    };

    for (final status in context.passStatuses) {
      if (status.availability == LivePassAvailability.available ||
          status.availability == LivePassAvailability.unknown) {
        continue;
      }

      final preference = preferenceById[status.facilityId];
      if (preference == null) continue;

      final dependsOnPass = switch (status.type) {
        LivePassType.dpa => preference.accessMethod == FacilityAccessMethod.dpa ||
            preference.useDpa,
        LivePassType.priorityPass =>
          preference.accessMethod == FacilityAccessMethod.priorityPass ||
              preference.usePriorityPass,
        _ => false,
      };
      if (!dependsOnPass) continue;

      final facility = _facilityById(context.facilities, status.facilityId);
      result.add(
        ReplanningSuggestion(
          type: ReplanningActionType.passFallback,
          title: '${facility?.name ?? status.facilityId}の代替案を再評価',
          reason:
              '${status.type.label}が${status.availability.label}です。'
              '通常利用へ自動変更せず、諦める・別施設・別の体験方法を比較します。',
          urgency: ReplanningUrgency.high,
          facilityId: status.facilityId,
        ),
      );
    }
    return result;
  }

  List<ReplanningSuggestion> _routePickupSuggestions(
    ReplanningContext context,
  ) {
    final from = context.currentFacility;
    final destination = context.nextDestination;
    final usableMinutes = context.usableMinutesBeforeFixed;
    if (from == null || destination == null || usableMinutes == null) {
      return const <ReplanningSuggestion>[];
    }

    final candidates = routePickupService.candidates(
      from: from,
      destination: destination,
      facilities: context.facilities,
      preferences: context.preferences,
    );

    final result = <ReplanningSuggestion>[];
    for (final candidate in candidates) {
      final detourMinutes = _detourMinutes(
        from: from,
        pickup: candidate,
        destination: destination,
      );
      final requiredMinutes = candidate.durationMinutes + detourMinutes;
      if (requiredMinutes > usableMinutes) continue;

      result.add(
        ReplanningSuggestion(
          type: ReplanningActionType.routePickup,
          title: '${candidate.name}を動線上で回収',
          reason:
              '次の固定予定に間に合う範囲で、追加移動約$detourMinutes分・'
              '合計約$requiredMinutes分で回収できます。',
          urgency: ReplanningUrgency.normal,
          facilityId: candidate.id,
          availableMinutes: usableMinutes,
        ),
      );
    }
    return result;
  }

  int _detourMinutes({
    required Facility from,
    required Facility pickup,
    required Facility destination,
  }) {
    final direct = proximityService.distanceMeters(from, destination);
    final via = proximityService.distanceMeters(from, pickup) +
        proximityService.distanceMeters(pickup, destination);
    final extraMeters = (via - direct).clamp(0, double.infinity);
    return (extraMeters / walkingMetersPerMinute).ceil();
  }

  int _weatherScore(Facility facility, ReplanningContext context) {
    var score = _priorityScore(facility.priority) * 100;
    if (facility.isIndoor) score += 35;
    if (facility.isWaterRide) score -= 10;

    PlanPreference? preference;
    for (final item in context.preferences) {
      if (item.facilityId == facility.id) {
        preference = item;
        break;
      }
    }
    if (preference?.isExcluded ?? false) return -100000;
    return score;
  }

  int _priorityScore(PriorityLevel priority) => priority.value;

  String _hotelBreakReason(ReplanningContext context) {
    final reasons = <String>[];
    if (context.weather?.condition == LiveWeatherCondition.heavyRain) {
      reasons.add('強い雨');
    } else {
      reasons.add('雨');
    }
    if (context.fatigueLevel.needsRest) reasons.add('疲労');
    if (context.hasBaggage) reasons.add('荷物');
    return '${reasons.join('・')}を考慮し、ホテルで休憩・荷物整理してから再入園する案を提示します。';
  }

  Facility? _facilityById(List<Facility> facilities, String id) {
    for (final facility in facilities) {
      if (facility.id == id) return facility;
    }
    return null;
  }
}

