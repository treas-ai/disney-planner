import '../../domain/entities/facility.dart';
import '../../domain/entities/live_wait_time.dart';
import '../../domain/entities/plan_preference.dart';
import '../../domain/entities/schedule_item.dart';
import '../../domain/enums/facility_access_method.dart';

enum LiveScheduleStatus {
  beforeParkOpen,
  current,
  upcoming,
  freeTime,
  completed,
  noSchedule,
  parkMismatch,
}

enum LiveWaitTimeKind { manual, facilityEstimate, passEstimate, unknown }

class LiveWaitTimeDisplay {
  const LiveWaitTimeDisplay({
    required this.kind,
    required this.label,
    required this.waitMinutes,
    required this.isStale,
    this.updatedAt,
  });

  final LiveWaitTimeKind kind;
  final String label;
  final int? waitMinutes;
  final bool isStale;
  final DateTime? updatedAt;

  bool get hasWaitMinutes {
    return waitMinutes != null;
  }

  bool get isManual {
    return kind == LiveWaitTimeKind.manual;
  }

  bool get isEstimated {
    return kind == LiveWaitTimeKind.facilityEstimate ||
        kind == LiveWaitTimeKind.passEstimate;
  }
}

class LiveScheduleSnapshot {
  const LiveScheduleSnapshot({
    required this.now,
    required this.status,
    required this.completedItemCount,
    required this.totalItemCount,
    this.currentItem,
    this.nextItem,
    this.currentFacility,
    this.nextFacility,
    this.currentPreference,
    this.nextPreference,
    this.currentWaitTime,
    this.nextWaitTime,
    this.minutesUntilNext,
    this.currentRemainingMinutes,
    this.freeTimeMinutes,
    this.nextExpectedEndAt,
    this.canCompleteNextBeforeFollowingItem = true,
    this.followingItem,
  });

  final DateTime now;
  final LiveScheduleStatus status;

  final int completedItemCount;
  final int totalItemCount;

  final ScheduleItem? currentItem;
  final ScheduleItem? nextItem;
  final ScheduleItem? followingItem;

  final Facility? currentFacility;
  final Facility? nextFacility;

  final PlanPreference? currentPreference;
  final PlanPreference? nextPreference;

  final LiveWaitTimeDisplay? currentWaitTime;
  final LiveWaitTimeDisplay? nextWaitTime;

  final int? minutesUntilNext;
  final int? currentRemainingMinutes;
  final int? freeTimeMinutes;

  final DateTime? nextExpectedEndAt;

  final bool canCompleteNextBeforeFollowingItem;

  bool get hasSchedule {
    return totalItemCount > 0;
  }

  bool get hasCurrentItem {
    return currentItem != null;
  }

  bool get hasNextItem {
    return nextItem != null;
  }

  bool get hasFollowingItem {
    return followingItem != null;
  }

  bool get hasFreeTime {
    return freeTimeMinutes != null && freeTimeMinutes! > 0;
  }

  double get progress {
    if (totalItemCount <= 0) {
      return 0;
    }

    return completedItemCount / totalItemCount;
  }
}

extension FacilityAccessMethodLiveLabel on FacilityAccessMethod {
  String get liveShortLabel {
    return switch (this) {
      FacilityAccessMethod.standby => '通常待機',
      FacilityAccessMethod.dpa => 'DPA',
      FacilityAccessMethod.priorityPass => 'プライオリティパス',
      FacilityAccessMethod.standbyPass => 'スタンバイパス',
      FacilityAccessMethod.entryRequest => 'エントリー受付',
      FacilityAccessMethod.reservation => '予約利用',
      FacilityAccessMethod.freeSeating => '自由席・自由鑑賞',
    };
  }
}

extension LiveWaitTimeFormatting on LiveWaitTime {
  String updatedAgeLabel(DateTime now) {
    final difference = now.difference(updatedAt);

    if (difference.isNegative || difference.inMinutes < 1) {
      return 'たった今更新';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分前更新';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}時間前更新';
    }

    return '${difference.inDays}日前更新';
  }
}
