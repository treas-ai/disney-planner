import '../../domain/entities/facility.dart';
import '../../domain/entities/plan_preference.dart';
import '../../domain/entities/schedule_item.dart';
import '../../domain/enums/facility_access_method.dart';
import '../../domain/enums/facility_category.dart';
import 'live_controller.dart';
import 'live_models.dart';

enum LiveRecommendationLevel {
  highlyRecommended(label: '今行くのがおすすめ', stars: 5),
  recommended(label: 'おすすめ', stars: 4),
  available(label: '時間に余裕があります', stars: 3),
  caution(label: '時間に注意', stars: 2),
  unavailable(label: '今はおすすめできません', stars: 1);

  const LiveRecommendationLevel({required this.label, required this.stars});

  final String label;
  final int stars;

  String get starLabel {
    return '${'★' * stars}${'☆' * (5 - stars)}';
  }
}

class LiveRecommendation {
  const LiveRecommendation({
    required this.facility,
    required this.preference,
    required this.waitTime,
    required this.level,
    required this.score,
    required this.reason,
    required this.expectedStartAt,
    required this.expectedEndAt,
    required this.totalRequiredMinutes,
    required this.availableMinutes,
    required this.canCompleteBeforeFixedSchedule,
    this.nextFixedSchedule,
  });

  final Facility facility;
  final PlanPreference? preference;
  final LiveWaitTimeDisplay waitTime;

  final LiveRecommendationLevel level;
  final int score;
  final String reason;

  final DateTime expectedStartAt;
  final DateTime expectedEndAt;

  final int totalRequiredMinutes;
  final int? availableMinutes;

  final bool canCompleteBeforeFixedSchedule;

  final ScheduleItem? nextFixedSchedule;

  bool get hasNextFixedSchedule {
    return nextFixedSchedule != null;
  }

  int? get remainingMinutesAfterCompletion {
    final available = availableMinutes;

    if (available == null) {
      return null;
    }

    return available - totalRequiredMinutes;
  }
}

class LiveRecommendationResult {
  const LiveRecommendationResult({
    required this.recommendations,
    required this.evaluatedAt,
    this.nextFixedSchedule,
  });

  final List<LiveRecommendation> recommendations;
  final DateTime evaluatedAt;
  final ScheduleItem? nextFixedSchedule;

  bool get hasRecommendations {
    return recommendations.isNotEmpty;
  }

  LiveRecommendation? get bestRecommendation {
    if (recommendations.isEmpty) {
      return null;
    }

    return recommendations.first;
  }
}

class LiveRecommendationEvaluator {
  const LiveRecommendationEvaluator({
    this.movementBufferMinutes = 15,
    this.minimumSafetyMarginMinutes = 10,
  });

  final int movementBufferMinutes;
  final int minimumSafetyMarginMinutes;

  LiveRecommendationResult evaluate({required LiveController controller}) {
    final now = controller.now;
    final schedule = controller.schedule;

    if (schedule == null ||
        schedule.items.isEmpty ||
        !controller.scheduleMatchesCurrentPark) {
      return LiveRecommendationResult(
        recommendations: const [],
        evaluatedAt: now,
      );
    }

    final currentMinutes = _minutesOfDay(now);

    final sortedItems = List<ScheduleItem>.of(schedule.items)
      ..sort((left, right) {
        return _itemStartMinutes(left).compareTo(_itemStartMinutes(right));
      });

    final nextFixedSchedule = _findNextFixedSchedule(
      controller: controller,
      items: sortedItems,
      currentMinutes: currentMinutes,
    );

    final nextFixedStartAt = nextFixedSchedule == null
        ? null
        : _dateTimeForItemStart(now: now, item: nextFixedSchedule);

    final candidateFacilityIds = <String>{};
    final candidates = <LiveRecommendation>[];

    for (final item in sortedItems) {
      final facility = controller.facilityById(item.facilityId);

      if (facility == null ||
          facility.category != FacilityCategory.attraction ||
          !facility.isOpen) {
        continue;
      }

      if (!candidateFacilityIds.add(facility.id)) {
        continue;
      }

      if (_itemEndMinutes(item) <= currentMinutes) {
        continue;
      }

      final preference = controller.preferenceByFacilityId(facility.id);

      final waitTime = _resolveWaitTime(
        controller: controller,
        facility: facility,
        preference: preference,
        now: now,
      );

      final recommendation = _evaluateFacility(
        facility: facility,
        preference: preference,
        waitTime: waitTime,
        now: now,
        nextFixedSchedule: nextFixedSchedule,
        nextFixedStartAt: nextFixedStartAt,
        originalScheduleItem: item,
      );

      candidates.add(recommendation);
    }

    candidates.sort((left, right) {
      final scoreComparison = right.score.compareTo(left.score);

      if (scoreComparison != 0) {
        return scoreComparison;
      }

      final leftWait = left.waitTime.waitMinutes ?? 9999;

      final rightWait = right.waitTime.waitMinutes ?? 9999;

      final waitComparison = leftWait.compareTo(rightWait);

      if (waitComparison != 0) {
        return waitComparison;
      }

      return left.facility.name.compareTo(right.facility.name);
    });

    return LiveRecommendationResult(
      recommendations: List<LiveRecommendation>.unmodifiable(candidates),
      evaluatedAt: now,
      nextFixedSchedule: nextFixedSchedule,
    );
  }

  LiveRecommendation _evaluateFacility({
    required Facility facility,
    required PlanPreference? preference,
    required LiveWaitTimeDisplay waitTime,
    required DateTime now,
    required ScheduleItem? nextFixedSchedule,
    required DateTime? nextFixedStartAt,
    required ScheduleItem originalScheduleItem,
  }) {
    final waitMinutes = waitTime.waitMinutes;

    final experienceMinutes = facility.durationMinutes > 0
        ? facility.durationMinutes
        : _scheduledDurationMinutes(originalScheduleItem);

    final effectiveWaitMinutes = waitMinutes ?? 30;

    final totalRequiredMinutes =
        movementBufferMinutes + effectiveWaitMinutes + experienceMinutes;

    final expectedStartAt = now.add(Duration(minutes: movementBufferMinutes));

    final expectedEndAt = now.add(Duration(minutes: totalRequiredMinutes));

    final availableMinutes = nextFixedStartAt?.difference(now).inMinutes;

    final canComplete =
        nextFixedStartAt == null ||
        !expectedEndAt
            .add(Duration(minutes: minimumSafetyMarginMinutes))
            .isAfter(nextFixedStartAt);

    var score = 50;

    score += _priorityScore(preference);

    score += _accessMethodScore(facility: facility, preference: preference);

    score += _waitTimeScore(waitMinutes);

    if (waitTime.isStale) {
      score -= 15;
    }

    if (waitMinutes == null) {
      score -= 12;
    }

    if (canComplete) {
      score += 15;
    } else {
      score -= 60;
    }

    final remainingAfterCompletion = availableMinutes == null
        ? null
        : availableMinutes - totalRequiredMinutes;

    if (remainingAfterCompletion != null) {
      if (remainingAfterCompletion >= 60) {
        score += 15;
      } else if (remainingAfterCompletion >= 30) {
        score += 10;
      } else if (remainingAfterCompletion >= minimumSafetyMarginMinutes) {
        score += 3;
      } else if (remainingAfterCompletion >= 0) {
        score -= 10;
      } else {
        score -= 35;
      }
    }

    score = score.clamp(0, 100);

    final level = _recommendationLevel(
      score: score,
      canComplete: canComplete,
      remainingAfterCompletion: remainingAfterCompletion,
      waitTimeUnknown: waitMinutes == null,
      waitTimeStale: waitTime.isStale,
    );

    final reason = _buildReason(
      facility: facility,
      preference: preference,
      waitTime: waitTime,
      totalRequiredMinutes: totalRequiredMinutes,
      availableMinutes: availableMinutes,
      remainingAfterCompletion: remainingAfterCompletion,
      canComplete: canComplete,
      nextFixedSchedule: nextFixedSchedule,
    );

    return LiveRecommendation(
      facility: facility,
      preference: preference,
      waitTime: waitTime,
      level: level,
      score: score,
      reason: reason,
      expectedStartAt: expectedStartAt,
      expectedEndAt: expectedEndAt,
      totalRequiredMinutes: totalRequiredMinutes,
      availableMinutes: availableMinutes,
      canCompleteBeforeFixedSchedule: canComplete,
      nextFixedSchedule: nextFixedSchedule,
    );
  }

  ScheduleItem? _findNextFixedSchedule({
    required LiveController controller,
    required List<ScheduleItem> items,
    required int currentMinutes,
  }) {
    for (final item in items) {
      if (_itemStartMinutes(item) <= currentMinutes) {
        continue;
      }

      final facility = controller.facilityById(item.facilityId);

      if (_isFixedSchedule(
        controller: controller,
        item: item,
        facility: facility,
      )) {
        return item;
      }
    }

    return null;
  }

  bool _isFixedSchedule({
    required LiveController controller,
    required ScheduleItem item,
    required Facility? facility,
  }) {
    if (facility == null) {
      return item.type.name == 'lunch' ||
          item.type.name == 'dinner' ||
          item.type.name == 'breakfast' ||
          item.type.name == 'exit';
    }

    final preference = controller.preferenceByFacilityId(facility.id);

    if (facility.category == FacilityCategory.show ||
        facility.category == FacilityCategory.parade) {
      return true;
    }

    if (facility.isRestaurant) {
      return preference?.reservationTime.trim().isNotEmpty ?? false;
    }

    return false;
  }

  LiveWaitTimeDisplay _resolveWaitTime({
    required LiveController controller,
    required Facility facility,
    required PlanPreference? preference,
    required DateTime now,
  }) {
    final passWaitTime = _resolvePassWaitTime(
      facility: facility,
      preference: preference,
    );

    if (passWaitTime != null) {
      return passWaitTime;
    }

    final manualWaitTime = controller.manualWaitTimeByFacilityId(facility.id);

    if (manualWaitTime != null) {
      return LiveWaitTimeDisplay(
        kind: LiveWaitTimeKind.manual,
        label: '手動入力',
        waitMinutes: manualWaitTime.waitMinutes,
        isStale: manualWaitTime.isStaleAt(now),
        updatedAt: manualWaitTime.updatedAt,
      );
    }

    final facilityWaitMinutes = facility.waitTime?.minutes;

    if (facilityWaitMinutes != null) {
      return LiveWaitTimeDisplay(
        kind: LiveWaitTimeKind.facilityEstimate,
        label: '施設データの目安',
        waitMinutes: facilityWaitMinutes,
        isStale: false,
      );
    }

    return const LiveWaitTimeDisplay(
      kind: LiveWaitTimeKind.unknown,
      label: '待ち時間不明',
      waitMinutes: null,
      isStale: false,
    );
  }

  LiveWaitTimeDisplay? _resolvePassWaitTime({
    required Facility facility,
    required PlanPreference? preference,
  }) {
    final accessMethod =
        preference?.accessMethod ?? FacilityAccessMethod.standby;

    return switch (accessMethod) {
      FacilityAccessMethod.dpa when facility.supportsDpa =>
        const LiveWaitTimeDisplay(
          kind: LiveWaitTimeKind.passEstimate,
          label: 'DPA利用時の目安',
          waitMinutes: 10,
          isStale: false,
        ),
      FacilityAccessMethod.priorityPass when facility.supportsPriorityPass =>
        const LiveWaitTimeDisplay(
          kind: LiveWaitTimeKind.passEstimate,
          label: 'プライオリティパス利用時の目安',
          waitMinutes: 15,
          isStale: false,
        ),
      FacilityAccessMethod.standbyPass when facility.supportsStandbyPass =>
        const LiveWaitTimeDisplay(
          kind: LiveWaitTimeKind.passEstimate,
          label: 'スタンバイパス利用時の目安',
          waitMinutes: 20,
          isStale: false,
        ),
      _ => null,
    };
  }

  int _priorityScore(PlanPreference? preference) {
    return switch (preference?.priority.name) {
      'highest' => 25,
      'high' => 18,
      'medium' => 10,
      'low' => 3,
      'lowest' => 0,
      _ => 8,
    };
  }

  int _accessMethodScore({
    required Facility facility,
    required PlanPreference? preference,
  }) {
    final accessMethod =
        preference?.accessMethod ?? FacilityAccessMethod.standby;

    return switch (accessMethod) {
      FacilityAccessMethod.dpa when facility.supportsDpa => 20,
      FacilityAccessMethod.priorityPass when facility.supportsPriorityPass =>
        16,
      FacilityAccessMethod.standbyPass when facility.supportsStandbyPass => 10,
      FacilityAccessMethod.standby => 0,
      _ => 2,
    };
  }

  int _waitTimeScore(int? waitMinutes) {
    if (waitMinutes == null) {
      return -8;
    }

    if (waitMinutes <= 15) {
      return 25;
    }

    if (waitMinutes <= 30) {
      return 20;
    }

    if (waitMinutes <= 45) {
      return 12;
    }

    if (waitMinutes <= 60) {
      return 5;
    }

    if (waitMinutes <= 90) {
      return -5;
    }

    if (waitMinutes <= 120) {
      return -15;
    }

    return -25;
  }

  LiveRecommendationLevel _recommendationLevel({
    required int score,
    required bool canComplete,
    required int? remainingAfterCompletion,
    required bool waitTimeUnknown,
    required bool waitTimeStale,
  }) {
    if (!canComplete) {
      return LiveRecommendationLevel.unavailable;
    }

    if (remainingAfterCompletion != null &&
        remainingAfterCompletion < minimumSafetyMarginMinutes) {
      return LiveRecommendationLevel.caution;
    }

    if (waitTimeUnknown || waitTimeStale) {
      if (score >= 65) {
        return LiveRecommendationLevel.available;
      }

      return LiveRecommendationLevel.caution;
    }

    if (score >= 85) {
      return LiveRecommendationLevel.highlyRecommended;
    }

    if (score >= 70) {
      return LiveRecommendationLevel.recommended;
    }

    if (score >= 50) {
      return LiveRecommendationLevel.available;
    }

    if (score >= 30) {
      return LiveRecommendationLevel.caution;
    }

    return LiveRecommendationLevel.unavailable;
  }

  String _buildReason({
    required Facility facility,
    required PlanPreference? preference,
    required LiveWaitTimeDisplay waitTime,
    required int totalRequiredMinutes,
    required int? availableMinutes,
    required int? remainingAfterCompletion,
    required bool canComplete,
    required ScheduleItem? nextFixedSchedule,
  }) {
    final reasons = <String>[];

    final waitMinutes = waitTime.waitMinutes;

    if (waitMinutes == null) {
      reasons.add(
        '待ち時間が不明なため、'
        '30分として仮計算しています。',
      );
    } else {
      reasons.add(
        '待ち時間$waitMinutes分、'
        '移動と体験を含めて'
        '約$totalRequiredMinutes分必要です。',
      );
    }

    if (waitTime.isStale) {
      reasons.add(
        '待ち時間情報が古いため、'
        '現地で再確認してください。',
      );
    }

    final accessMethod = preference?.accessMethod;

    if (accessMethod != null && accessMethod != FacilityAccessMethod.standby) {
      reasons.add(
        '${accessMethod.liveShortLabel}の'
        '利用条件を考慮しています。',
      );
    }

    if (nextFixedSchedule != null && availableMinutes != null) {
      reasons.add(
        '次の固定予定'
        '「${nextFixedSchedule.title}」まで'
        '$availableMinutes分あります。',
      );

      if (canComplete && remainingAfterCompletion != null) {
        reasons.add(
          '終了後に約'
          '$remainingAfterCompletion分の'
          '余裕があります。',
        );
      } else if (!canComplete) {
        reasons.add(
          '現在の待ち時間では'
          '次の固定予定に間に合わない'
          '可能性があります。',
        );
      }
    } else {
      reasons.add('この後に近い固定予定はありません。');
    }

    return reasons.join(' ');
  }

  int _scheduledDurationMinutes(ScheduleItem item) {
    final duration = _itemEndMinutes(item) - _itemStartMinutes(item);

    return duration > 0 ? duration : 60;
  }

  DateTime _dateTimeForItemStart({
    required DateTime now,
    required ScheduleItem item,
  }) {
    return DateTime(
      now.year,
      now.month,
      now.day,
      item.startHour,
      item.startMinute,
    );
  }

  int _minutesOfDay(DateTime value) {
    return value.hour * 60 + value.minute;
  }

  int _itemStartMinutes(ScheduleItem item) {
    return item.startHour * 60 + item.startMinute;
  }

  int _itemEndMinutes(ScheduleItem item) {
    return item.endHour * 60 + item.endMinute;
  }
}
