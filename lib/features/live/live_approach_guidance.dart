import '../../domain/entities/facility.dart';
import '../../domain/entities/plan_preference.dart';
import '../../domain/entities/schedule_item.dart';
import '../../domain/enums/facility_category.dart';
import 'live_controller.dart';

enum LiveApproachStage {
  normal,
  prepare,
  recommended,
  moveNow,
  hurry,
  imminent,
  inProgress,
}

class LiveApproachGuidance {
  const LiveApproachGuidance({
    required this.item,
    required this.facility,
    required this.preference,
    required this.stage,
    required this.minutesUntilStart,
    required this.recommendedLeadMinutes,
    required this.title,
    required this.message,
    required this.reason,
  });

  final ScheduleItem item;
  final Facility? facility;
  final PlanPreference? preference;

  final LiveApproachStage stage;

  /// 開始前は正数、開始時刻は0、開始後は負数。
  final int minutesUntilStart;

  /// 施設ごとに設定した推奨移動開始時間。
  final int recommendedLeadMinutes;

  final String title;
  final String message;
  final String reason;

  bool get isInProgress {
    return stage == LiveApproachStage.inProgress;
  }

  bool get shouldEmphasize {
    return stage != LiveApproachStage.normal;
  }

  bool get isUrgent {
    return stage == LiveApproachStage.hurry ||
        stage == LiveApproachStage.imminent;
  }

  int get minutesUntilRecommendedDeparture {
    return minutesUntilStart - recommendedLeadMinutes;
  }
}

class LiveApproachGuidanceResolver {
  const LiveApproachGuidanceResolver();

  LiveApproachGuidance? resolve({required LiveController controller}) {
    final schedule = controller.schedule;

    if (schedule == null ||
        schedule.items.isEmpty ||
        !controller.scheduleMatchesCurrentPark) {
      return null;
    }

    final now = controller.now;
    final currentMinutes = now.hour * 60 + now.minute;

    final sortedItems = List<ScheduleItem>.of(schedule.items)
      ..sort((left, right) {
        return _startMinutes(left).compareTo(_startMinutes(right));
      });

    for (final item in sortedItems) {
      final startMinutes = _startMinutes(item);
      final endMinutes = _endMinutes(item);

      final facility = controller.facilityById(item.facilityId);

      final preference = controller.preferenceByFacilityId(item.facilityId);

      if (!_isGuidanceTarget(
        item: item,
        facility: facility,
        preference: preference,
      )) {
        continue;
      }

      if (currentMinutes >= startMinutes && currentMinutes < endMinutes) {
        final leadMinutes = _recommendedLeadMinutes(
          item: item,
          facility: facility,
          preference: preference,
        );

        return LiveApproachGuidance(
          item: item,
          facility: facility,
          preference: preference,
          stage: LiveApproachStage.inProgress,
          minutesUntilStart: startMinutes - currentMinutes,
          recommendedLeadMinutes: leadMinutes,
          title: _inProgressTitle(facility),
          message: '${item.title}は現在進行中です。',
          reason: _guidanceReason(
            item: item,
            facility: facility,
            preference: preference,
            leadMinutes: leadMinutes,
          ),
        );
      }

      if (startMinutes <= currentMinutes) {
        continue;
      }

      final minutesUntilStart = startMinutes - currentMinutes;

      final leadMinutes = _recommendedLeadMinutes(
        item: item,
        facility: facility,
        preference: preference,
      );

      final stage = _resolveStage(
        minutesUntilStart: minutesUntilStart,
        recommendedLeadMinutes: leadMinutes,
      );

      return LiveApproachGuidance(
        item: item,
        facility: facility,
        preference: preference,
        stage: stage,
        minutesUntilStart: minutesUntilStart,
        recommendedLeadMinutes: leadMinutes,
        title: _stageTitle(stage: stage, facility: facility),
        message: _stageMessage(
          stage: stage,
          item: item,
          facility: facility,
          minutesUntilStart: minutesUntilStart,
          recommendedLeadMinutes: leadMinutes,
        ),
        reason: _guidanceReason(
          item: item,
          facility: facility,
          preference: preference,
          leadMinutes: leadMinutes,
        ),
      );
    }

    return null;
  }

  bool _isGuidanceTarget({
    required ScheduleItem item,
    required Facility? facility,
    required PlanPreference? preference,
  }) {
    if (facility == null) {
      return false;
    }

    if (_isShowOrParade(facility)) {
      return true;
    }

    if (facility.isRestaurant) {
      final hasReservation =
          preference?.reservationTime.trim().isNotEmpty ?? false;

      return hasReservation ||
          facility.requiresReservation ||
          facility.reservationRequired ||
          facility.supportsPrioritySeating ||
          facility.supportsMobileOrder;
    }

    return false;
  }

  int _recommendedLeadMinutes({
    required ScheduleItem item,
    required Facility? facility,
    required PlanPreference? preference,
  }) {
    if (facility == null) {
      return 30;
    }

    final normalizedName = _normalizeName(facility.name);

    if (_containsAny(normalizedName, const ['ビリーヴ', 'believe'])) {
      return 45;
    }

    if (_isShowOrParade(facility) && _isMediterraneanHarbor(facility.areaId)) {
      return 40;
    }

    if (_containsAny(normalizedName, const [
      'ビッグバンドビート',
      'bigbandbeat',
      'bbb',
    ])) {
      return 25;
    }

    if (_containsAny(normalizedName, const [
      'ジャンボリミッキー',
      'ジャンボリ',
      'jamboreemickey',
      'jamboree',
    ])) {
      return 20;
    }

    if (facility.isRestaurant) {
      final hasReservation =
          preference?.reservationTime.trim().isNotEmpty ?? false;

      if (hasReservation ||
          facility.requiresReservation ||
          facility.reservationRequired ||
          facility.supportsPrioritySeating) {
        return 30;
      }

      if (facility.supportsMobileOrder) {
        return 20;
      }
    }

    if (_isShowOrParade(facility)) {
      return 45;
    }

    return 30;
  }

  LiveApproachStage _resolveStage({
    required int minutesUntilStart,
    required int recommendedLeadMinutes,
  }) {
    if (minutesUntilStart <= 0) {
      return LiveApproachStage.inProgress;
    }

    if (minutesUntilStart <= 10) {
      return LiveApproachStage.imminent;
    }

    if (minutesUntilStart <= 20) {
      return LiveApproachStage.hurry;
    }

    if (minutesUntilStart <= recommendedLeadMinutes) {
      return LiveApproachStage.moveNow;
    }

    if (minutesUntilStart <= 30) {
      return LiveApproachStage.recommended;
    }

    if (minutesUntilStart <= 45) {
      return LiveApproachStage.prepare;
    }

    if (minutesUntilStart <= 60) {
      return LiveApproachStage.prepare;
    }

    return LiveApproachStage.normal;
  }

  String _stageTitle({
    required LiveApproachStage stage,
    required Facility? facility,
  }) {
    final isRestaurant = facility?.isRestaurant ?? false;

    return switch (stage) {
      LiveApproachStage.normal => '次の固定予定',
      LiveApproachStage.prepare => 'そろそろ準備',
      LiveApproachStage.recommended => '移動を検討',
      LiveApproachStage.moveNow =>
        isRestaurant ? 'レストランへ向かいましょう' : '鑑賞場所へ向かいましょう',
      LiveApproachStage.hurry => '早めに移動してください',
      LiveApproachStage.imminent => 'まもなく開始',
      LiveApproachStage.inProgress => '進行中',
    };
  }

  String _inProgressTitle(Facility? facility) {
    if (facility?.isRestaurant ?? false) {
      return '予約時間です';
    }

    if (facility != null && _isShowOrParade(facility)) {
      return '公演中';
    }

    return '進行中';
  }

  String _stageMessage({
    required LiveApproachStage stage,
    required ScheduleItem item,
    required Facility? facility,
    required int minutesUntilStart,
    required int recommendedLeadMinutes,
  }) {
    final eventLabel = _eventLabel(facility);

    final minutesUntilDeparture = minutesUntilStart - recommendedLeadMinutes;

    return switch (stage) {
      LiveApproachStage.normal =>
        '$eventLabel「${item.title}」まで'
            'あと$minutesUntilStart分です。',
      LiveApproachStage.prepare =>
        minutesUntilDeparture > 0
            ? '$eventLabel「${item.title}」まで'
                  'あと$minutesUntilStart分です。'
                  '推奨移動開始まであと'
                  '$minutesUntilDeparture分です。'
            : '$eventLabel「${item.title}」へ向かう準備をしてください。',
      LiveApproachStage.recommended =>
        '$eventLabel「${item.title}」まで'
            'あと$minutesUntilStart分です。'
            '移動を開始することをおすすめします。',
      LiveApproachStage.moveNow =>
        '$eventLabel「${item.title}」まで'
            'あと$minutesUntilStart分です。'
            '推奨移動開始時刻になりました。',
      LiveApproachStage.hurry =>
        '$eventLabel「${item.title}」まで'
            'あと$minutesUntilStart分です。'
            '現在地を確認し、早めに移動してください。',
      LiveApproachStage.imminent =>
        '$eventLabel「${item.title}」まで'
            'あと$minutesUntilStart分です。'
            '受付・鑑賞場所を確認してください。',
      LiveApproachStage.inProgress => '$eventLabel「${item.title}」は現在進行中です。',
    };
  }

  String _guidanceReason({
    required ScheduleItem item,
    required Facility? facility,
    required PlanPreference? preference,
    required int leadMinutes,
  }) {
    if (facility == null) {
      return '推奨移動開始は$leadMinutes分前です。';
    }

    final normalizedName = _normalizeName(facility.name);

    if (_containsAny(normalizedName, const ['ビリーヴ', 'believe'])) {
      return '鑑賞場所の確保とハーバー周辺への移動を考慮し、'
          '45分前からの移動を推奨しています。';
    }

    if (_isShowOrParade(facility) && _isMediterraneanHarbor(facility.areaId)) {
      return 'メディテレーニアンハーバー周辺への移動と'
          '鑑賞場所の確認を考慮し、40分前からの移動を推奨しています。';
    }

    if (_containsAny(normalizedName, const [
      'ビッグバンドビート',
      'bigbandbeat',
      'bbb',
    ])) {
      return '会場への移動と入場手続きを考慮し、'
          '25分前からの移動を推奨しています。';
    }

    if (_containsAny(normalizedName, const [
      'ジャンボリミッキー',
      'ジャンボリ',
      'jamboreemickey',
      'jamboree',
    ])) {
      return '会場への移動と入場確認を考慮し、'
          '20分前からの移動を推奨しています。';
    }

    if (facility.isRestaurant) {
      final hasReservation =
          preference?.reservationTime.trim().isNotEmpty ?? false;

      if (hasReservation ||
          facility.requiresReservation ||
          facility.reservationRequired ||
          facility.supportsPrioritySeating) {
        return '店舗への移動と受付・チェックインを考慮し、'
            '30分前からの移動を推奨しています。';
      }

      if (facility.supportsMobileOrder) {
        return '店舗への移動と受取準備を考慮し、'
            '20分前からの移動を推奨しています。';
      }
    }

    if (_isShowOrParade(facility)) {
      return '鑑賞場所への移動と入場確認を考慮し、'
          '$leadMinutes分前からの移動を推奨しています。';
    }

    return '移動と受付の余裕を考慮し、'
        '$leadMinutes分前からの移動を推奨しています。';
  }

  String _eventLabel(Facility? facility) {
    if (facility == null) {
      return '予定';
    }

    if (facility.isRestaurant) {
      if (facility.supportsMobileOrder &&
          !facility.requiresReservation &&
          !facility.reservationRequired &&
          !facility.supportsPrioritySeating) {
        return 'モバイルオーダー受取';
      }

      return 'レストラン予約';
    }

    if (_isShowOrParade(facility)) {
      return 'ショー・パレード';
    }

    return '予定';
  }

  bool _isShowOrParade(Facility facility) {
    return facility.category == FacilityCategory.show ||
        facility.category == FacilityCategory.parade;
  }

  bool _isMediterraneanHarbor(String areaId) {
    final normalized = _normalizeName(areaId);

    return normalized.contains('mediterraneanharbor') ||
        normalized.contains('メディテレーニアンハーバー');
  }

  bool _containsAny(String value, List<String> candidates) {
    for (final candidate in candidates) {
      if (value.contains(_normalizeName(candidate))) {
        return true;
      }
    }

    return false;
  }

  String _normalizeName(String value) {
    return value
        .toLowerCase()
        .replaceAll('！', '')
        .replaceAll('!', '')
        .replaceAll('・', '')
        .replaceAll(' ', '')
        .replaceAll('　', '')
        .replaceAll('-', '')
        .replaceAll('_', '');
  }

  int _startMinutes(ScheduleItem item) {
    return item.startHour * 60 + item.startMinute;
  }

  int _endMinutes(ScheduleItem item) {
    return item.endHour * 60 + item.endMinute;
  }
}
