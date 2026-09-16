import '../entities/day_schedule.dart';
import '../entities/plan_preference.dart';
import '../entities/plan_coverage_advice.dart';
import '../entities/schedule_item.dart';
import '../entities/schedule_validation_issue.dart';
import '../entities/trip_settings.dart';
import '../entities/today_access_result.dart';
import '../enums/facility_access_method.dart';
import '../enums/today_access_kind.dart';
import '../enums/today_access_status.dart';
import 'entry_prediction_service.dart';

enum PlanTextExportFormat {
  simple,
  evaluation,
}

class PlanTextExporter {
  const PlanTextExporter();

  String export({
    required DaySchedule schedule,
    required TripSettings settings,
    required String parkName,
    required List<PlanPreference> preferences,
    required List<ScheduleValidationIssue> validationIssues,
    required PlanTextExportFormat format,
    List<TodayAccessResult> todayAccessResults = const <TodayAccessResult>[],
    PlanCoverageAdvice? coverageAdvice,
  }) {
    return switch (format) {
      PlanTextExportFormat.simple => _simple(
          schedule: schedule,
          settings: settings,
          parkName: parkName,
        ),
      PlanTextExportFormat.evaluation => _evaluation(
          schedule: schedule,
          settings: settings,
          parkName: parkName,
          preferences: preferences,
          validationIssues: validationIssues,
          todayAccessResults: todayAccessResults,
          coverageAdvice: coverageAdvice,
        ),
    };
  }

  String _simple({
    required DaySchedule schedule,
    required TripSettings settings,
    required String parkName,
  }) {
    final entryPrediction = const EntryPredictionService().predict(settings);
    final buffer = StringBuffer()
      ..writeln('Disney Planner 簡易プラン')
      ..writeln()
      ..writeln('パーク：$parkName')
      ..writeln('来園日：${settings.visitDateLabel}')
      ..writeln('並び開始：${entryPrediction.queueArrivalLabel}')
      ..writeln('予測入園：${entryPrediction.expectedEntryLabel}')
      ..writeln(
        '滞在時間：${entryPrediction.expectedEntryLabel}〜'
        '${settings.exitTimeLabel}',
      )
      ..writeln('人数：${settings.numberOfPeople}人')
      ..writeln()
      ..writeln('【スケジュール】');

    for (final item in schedule.items) {
      buffer.writeln('${item.startTimeLabel}　${item.title}');
    }

    return buffer.toString().trimRight();
  }

  String _evaluation({
    required DaySchedule schedule,
    required TripSettings settings,
    required String parkName,
    required List<PlanPreference> preferences,
    required List<ScheduleValidationIssue> validationIssues,
    required List<TodayAccessResult> todayAccessResults,
    PlanCoverageAdvice? coverageAdvice,
  }) {
    final entryPrediction = const EntryPredictionService().predict(settings);
    final buffer = StringBuffer()
      ..writeln('Disney Planner AI評価用プラン')
      ..writeln()
      ..writeln('【基本情報】')
      ..writeln('パーク：$parkName')
      ..writeln('来園日：${settings.visitDateLabel}')
      ..writeln('並び開始：${entryPrediction.queueArrivalLabel}')
      ..writeln('公式開園予定：${entryPrediction.officialOpeningLabel}')
      ..writeln(
        entryPrediction.usesHappyEntryModel
            ? 'ハッピーエントリー開始：${entryPrediction.admissionStartLabel}'
            : '一般入園開始：${entryPrediction.admissionStartLabel}',
      )
      ..writeln('予測入園：${entryPrediction.expectedEntryLabel}')
      ..writeln('入園後の予約操作：${entryPrediction.postEntryOperationMinutes}分')
      ..writeln('最初の施設到着：${entryPrediction.firstFacilityArrivalLabel}')
      ..writeln(
        '最初の施設利用可能：'
        '${entryPrediction.firstFacilityAvailableLabel}',
      )
      ..writeln(
        '施設運営開始待ち：'
        '${entryPrediction.facilityOpeningWaitMinutes}分',
      )
      ..writeln('予測ゲート処理：${entryPrediction.gateDelayMinutes}分')
      ..writeln('退園予定：${settings.exitTimeLabel}')
      ..writeln('人数：${settings.numberOfPeople}人')
      ..writeln('雨天設定：${settings.isRainy ? 'あり' : 'なし'}')
      ..writeln('子ども連れ：${settings.hasChildren ? 'あり' : 'なし'}')
      ..writeln()
      ..writeln('【利用可能なサービス】')
      ..writeln('ハッピーエントリー：${_enabled(settings.hasHappyEntry)}')
      ..writeln(
        'アトラクションDPA：'
        '${settings.attractionDpaMaxUses <= 0 ? '使わない' : '最大${settings.attractionDpaMaxUses}個'}',
      )
      ..writeln('ショーDPA：エントリー受付落選後に別枠で検討')
      ..writeln('シングルライダー：${_enabled(settings.canUseSingleRider)}')
      ..writeln('バケーションパッケージ：${_enabled(settings.usesVacationPackage)}')
      ..writeln(
        '対象アトラクション乗り放題：'
        '${_enabled(settings.usesVacationPackage && settings.hasUnlimitedAttractionRides)}',
      )
      ..writeln(
        'フリードリンク特典：'
        '${_enabled(settings.usesVacationPackage && settings.usesFreeDrinkBenefit)}',
      );
    final acquiredDpaCount = todayAccessResults.where((result) =>
        (result.kind == TodayAccessKind.attractionDpa ||
            result.kind == TodayAccessKind.showDpa) &&
        (result.status == TodayAccessStatus.acquired ||
            result.status == TodayAccessStatus.won)).length;
    if (acquiredDpaCount > 0) {
      buffer.writeln(
        '当日実績：事前設定にかかわらず、実際に取得したDPA $acquiredDpaCount件を固定条件として優先',
      );
    }
    buffer
      ..writeln()
      ..writeln('【スケジュール】');

    for (final item in schedule.items) {
      buffer
        ..writeln('${item.timeRangeLabel}　${item.title}')
        ..writeln('  種別：${item.type.label}');

      final preference = _preferenceFor(preferences, item.facilityId);
      if (preference != null) {
        final usesUnlimitedRide = _usesUnlimitedRide(item);
        buffer.writeln(
          '  利用方法：${usesUnlimitedRide ? 'バケパ乗り放題' : preference.accessMethod.label}',
        );
        if (preference.memo.trim().isNotEmpty) {
          buffer.writeln('  希望メモ：${preference.memo.trim()}');
        }
      }
      if (item.effectiveQueueMinutes != null && item.experienceMinutes != null) {
        final queueMinutes = item.effectiveQueueMinutes!;
        final totalMinutes = queueMinutes + item.experienceMinutes!;
        final usesUnlimitedRide = _usesUnlimitedRide(item);
        final usesPriorityAccess = _usesPriorityAccess(item);
        buffer
          ..writeln(
            usesPriorityAccess
                ? '  ${usesUnlimitedRide ? '優先入口利用バッファ' : '優先利用バッファ'}：$queueMinutes分'
                : '  推定待ち時間：$queueMinutes分',
          )
          ..writeln('  体験時間：${item.experienceMinutes}分')
          ..writeln('  合計拘束時間：$totalMinutes分');
        if ((item.waitEstimateSource ?? '').trim().isNotEmpty) {
          buffer.writeln(
            usesPriorityAccess
                ? '  バッファ設定根拠：${item.waitEstimateSource}'
                : '  待ち時間推定根拠：${item.waitEstimateSource}',
          );
        }
      }
      if ((item.reason ?? '').trim().isNotEmpty) {
        buffer.writeln('  AI理由：${_sanitizeLegacyReason(item.reason!.trim())}');
      }
      if ((item.note ?? '').trim().isNotEmpty) {
        buffer.writeln('  注意・メモ：${item.note!.trim()}');
      }
    }

    buffer
      ..writeln()
      ..writeln('【集計】')
      ..writeln('予定数：${schedule.items.length}件')
      ..writeln('固定・時間指定候補：${_fixedPreferenceCount(preferences)}件')
      ..writeln('DPA予定候補：${_accessCount(preferences, FacilityAccessMethod.dpa)}件')
      ..writeln('当日DPA取得済み：$acquiredDpaCount件');

    if (coverageAdvice != null) {
      buffer
        ..writeln()
        ..writeln('【やりたいこと達成 / DPA分析】')
        ..writeln(
          '現在の達成数：${coverageAdvice.currentScheduledCount}/${coverageAdvice.totalDesiredCount}件',
        );
      if (coverageAdvice.unmetFacilities.isEmpty) {
        buffer.writeln('未採用の希望：なし');
      } else {
        buffer.writeln('未採用の希望：');
        for (final item in coverageAdvice.unmetFacilities) {
          final rescue = item.firstRescuedAtDpaCount == null
              ? ''
              : '（DPA ${item.firstRescuedAtDpaCount}個シミュレーションで採用）';
          buffer.writeln('・${item.name}$rescue：${item.reason}');
        }
      }
      if (coverageAdvice.minimumDpaCountForAll != null) {
        buffer.writeln(
          '全希望を組み込む推定最少DPA数：${coverageAdvice.minimumDpaCountForAll}個',
        );
      } else {
        buffer.writeln(
          '全希望を組み込む推定最少DPA数：未達（最大${coverageAdvice.simulatedMaxDpaCount}個までシミュレーション）',
        );
      }
      if (coverageAdvice.dpaAcquisitionOrder.isNotEmpty) {
        buffer.writeln('Planner推奨DPA取得優先順：');
        final visibleCount = coverageAdvice.minimumDpaCountForAll ??
            coverageAdvice.dpaAcquisitionOrder.length;
        for (final item in coverageAdvice.dpaAcquisitionOrder.take(visibleCount)) {
          buffer.writeln('・${item.order}. ${item.name}：${item.reason}');
        }
      }
      buffer.writeln('※ DPA順はリアルタイム在庫予測ではなく、希望優先度・通常待機負担・時間短縮を基準にしたPlanner推奨です。');
    }

    buffer
      ..writeln()
      ..writeln('【検証結果】');

    if (validationIssues.isEmpty) {
      buffer.writeln('・自動検証で問題は見つかりませんでした。');
    } else {
      for (final issue in validationIssues) {
        buffer.writeln('・[${issue.severity.label}] ${issue.message}');
      }
    }

    buffer
      ..writeln()
      ..writeln('【改善を評価したい観点】')
      ..writeln('・最初に行きたい施設が適切な位置にあるか')
      ..writeln('・ショー、食事、固定予定の時刻が競合していないか')
      ..writeln('・同じエリアを往復する無駄な移動が多くないか')
      ..writeln('・待ち時間と予定数が現実的か')
      ..writeln('・休憩や食事の間隔が適切か')
      ..writeln('・DPAなどの利用効果が高い施設へ割り当てられているか');

    return buffer.toString().trimRight();
  }

  String _sanitizeLegacyReason(String value) {
    return value
        .replaceAll('PP代替', 'DPA対象状況')
        .replaceAll('PP利用可能時', 'DPA対象時')
        .replaceAll('PPと待ち時間', 'DPA対象状況と待ち時間');
  }

  String _enabled(bool value) => value ? '利用する' : '利用しない';

  bool _usesUnlimitedRide(ScheduleItem item) {
    if (item.usesVacationPackageUnlimited) return true;
    final source = item.waitEstimateSource?.trim() ?? '';
    return source.startsWith('バケーションパッケージ乗り放題') ||
        source.startsWith('バケパ乗り放題');
  }

  bool _usesPriorityAccess(ScheduleItem item) {
    if (item.usesPriorityAccessPlanning || _usesUnlimitedRide(item)) return true;
    final source = item.waitEstimateSource?.trim() ?? '';
    return source.contains('優先入口') ||
        source.contains('DPA') ||
        source.contains('プライオリティ') ||
        source.contains('パス利用時');
  }

  PlanPreference? _preferenceFor(
    List<PlanPreference> preferences,
    String? facilityId,
  ) {
    if (facilityId == null || facilityId.isEmpty) {
      return null;
    }
    for (final preference in preferences) {
      if (preference.facilityId == facilityId) {
        return preference;
      }
    }
    return null;
  }

  int _fixedPreferenceCount(List<PlanPreference> preferences) {
    return preferences.where((preference) {
      return preference.hasPreferredPerformanceTime ||
          preference.hasReservationTime ||
          preference.hasScheduledAccessTime;
    }).length;
  }

  int _accessCount(
    List<PlanPreference> preferences,
    FacilityAccessMethod method,
  ) {
    return preferences
        .where((preference) => preference.accessMethod == method)
        .length;
  }
}
