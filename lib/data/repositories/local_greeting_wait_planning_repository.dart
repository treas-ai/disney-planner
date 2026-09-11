import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/crowd_factor_profile.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/greeting_wait_planning_value.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/services/park_crowd_factor_estimator.dart';

class LocalGreetingWaitPlanningRepository {
  const LocalGreetingWaitPlanningRepository({
    this.crowdEstimator = const ParkCrowdFactorEstimator(),
  });

  static const String _planningAssetPath =
      'assets/master/greeting_wait_planning.json';
  static const String _charactersAssetPath = 'assets/master/characters.json';

  final ParkCrowdFactorEstimator crowdEstimator;

  Future<Map<String, GreetingWaitPlanningValue>> load({
    required String parkId,
    required DateTime targetDate,
    required List<Facility> facilities,
    required List<CrowdFactorProfile> crowdFactors,
  }) async {
    final planningRaw = await rootBundle.loadString(_planningAssetPath);
    final planningJson = jsonDecode(planningRaw) as Map<String, dynamic>;
    final planning =
        planningJson['planning'] as Map<String, dynamic>? ?? const {};
    final fallbackByPriority =
        planning['fallbackWaitMinutesByPriority'] as Map<String, dynamic>? ??
            const {};
    final maximumCrowdMultiplier =
        (planning['maximumParkCrowdMultiplier'] as num?)?.toDouble() ?? 1.75;
    final birthdayPlanningWaitMinutes =
        (planning['birthdayPlanningWaitMinutes'] as num?)?.toInt() ?? 240;
    final birthdayExtremeRiskMinutes =
        (planning['birthdayExtremeRiskMinutes'] as num?)?.toInt() ?? 480;
    final birthdayOpeningUrgencyBonus =
        (planning['birthdayOpeningUrgencyBonus'] as num?)?.toDouble() ?? 180;
    final roundingMinutes =
        ((planning['roundingMinutes'] as num?)?.toInt() ?? 5)
            .clamp(1, 60)
            .toInt();

    final charactersRaw = await rootBundle.loadString(_charactersAssetPath);
    final characters = (jsonDecode(charactersRaw) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    final birthdayCharactersByFacility = <String, List<String>>{};
    for (final character in characters) {
      final birthdayMonth = (character['birthdayMonth'] as num?)?.toInt();
      final birthdayDay = (character['birthdayDay'] as num?)?.toInt();
      if (birthdayMonth != targetDate.month || birthdayDay != targetDate.day) {
        continue;
      }
      final name = character['name'] as String? ?? '';
      final greetingIds =
          character['greetingFacilityIds'] as List<dynamic>? ?? const [];
      for (final value in greetingIds) {
        final id = value.toString();
        if (id.isEmpty) continue;
        birthdayCharactersByFacility.putIfAbsent(id, () => <String>[]).add(name);
      }
    }

    final crowdMultiplier = crowdEstimator.estimate(
      factors: crowdFactors,
      targetDate: targetDate,
      maximumMultiplier: maximumCrowdMultiplier,
    );

    final result = <String, GreetingWaitPlanningValue>{};
    for (final facility in facilities) {
      if (facility.parkId != parkId ||
          facility.category != FacilityCategory.greeting) {
        continue;
      }

      final configuredBase =
          (fallbackByPriority[facility.priority.name] as num?)?.toInt();
      final baseWaitMinutes = configuredBase ?? 30;
      final birthdayNames = birthdayCharactersByFacility[facility.id] ?? const [];
      final isBirthday = birthdayNames.isNotEmpty;

      final crowdedWait = _roundUp(
        (baseWaitMinutes * crowdMultiplier).round(),
        roundingMinutes,
      );
      final waitMinutes = isBirthday
          ? _roundUp(birthdayPlanningWaitMinutes, roundingMinutes)
          : crowdedWait;

      final source = isBirthday
          ? 'キャラクター記念日の特殊混雑日としてDisney Planner計画値を使用（実測値ではありません）'
          : crowdMultiplier > 1.001
              ? 'Git収集のパーク混雑傾向×グリーティング基準値によるDisney Planner計画値（実測値ではありません）'
              : 'グリーティング基準値によるDisney Planner計画値（実測値ではありません）';

      result[facility.id] = GreetingWaitPlanningValue(
        facilityId: facility.id,
        waitMinutes: waitMinutes,
        baseWaitMinutes: baseWaitMinutes,
        parkCrowdMultiplier: crowdMultiplier,
        isCharacterBirthday: isBirthday,
        birthdayCharacterNames: List<String>.unmodifiable(birthdayNames),
        birthdayPlanningWaitMinutes: birthdayPlanningWaitMinutes,
        birthdayExtremeRiskMinutes: birthdayExtremeRiskMinutes,
        birthdayOpeningUrgencyBonus: birthdayOpeningUrgencyBonus,
        source: source,
      );
    }

    return result;
  }

  int _roundUp(int minutes, int unit) {
    if (minutes <= 0) return 0;
    return ((minutes + unit - 1) ~/ unit) * unit;
  }
}
