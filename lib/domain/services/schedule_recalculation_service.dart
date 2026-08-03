import '../entities/day_schedule.dart';
import '../entities/live_operating_status.dart';
import '../entities/schedule_change.dart';
import '../entities/schedule_item.dart';
import '../entities/schedule_recalculation_request.dart';
import '../entities/schedule_recalculation_result.dart';
import '../enums/fixed_time_status.dart';
import '../enums/schedule_change_type.dart';
import '../enums/schedule_item_type.dart';
import 'schedule_engine.dart';

class ScheduleRecalculationService {
  const ScheduleRecalculationService({
    this.scheduleEngine = const ScheduleEngine(),
  });

  final ScheduleEngine scheduleEngine;

  ScheduleRecalculationResult createProposal(
    ScheduleRecalculationRequest request,
  ) {
    final nowMinutes = request.now.hour * 60 + request.now.minute;
    final preferenceById = {
      for (final preference in request.preferences)
        preference.facilityId: preference,
    };

    final preserved = request.currentSchedule.items
        .where((item) {
          final start = _start(item);
          final end = _end(item);
          if (item.type == ScheduleItemType.entry ||
              item.type == ScheduleItemType.exit) {
            return true;
          }
          if (end <= nowMinutes || (start <= nowMinutes && nowMinutes < end)) {
            return true;
          }
          final facilityId = item.facilityId;
          return facilityId != null &&
              preferenceById[facilityId]?.fixedTimeStatus ==
                  FixedTimeStatus.confirmed;
        })
        .toList(growable: false);

    final preservedFacilityIds = preserved
        .map((item) => item.facilityId)
        .whereType<String>()
        .toSet();
    final warnings = <String>[];

    final eligibleFacilities = request.facilities
        .where((facility) {
          if (preservedFacilityIds.contains(facility.id)) {
            return false;
          }
          final liveStatus = request.operatingStatuses[facility.id];
          if (liveStatus != null &&
              liveStatus.state != LiveOperatingState.operating &&
              liveStatus.state != LiveOperatingState.unknown) {
            warnings.add(
              '${facility.name}は${liveStatus.state.label}のため再配置対象から除外しました。',
            );
            return false;
          }
          if (!facility.isOpen) {
            warnings.add('${facility.name}は営業対象外のため再配置対象から除外しました。');
            return false;
          }
          final preference = preferenceById[facility.id];
          final liveWait = request.waitTimes[facility.id];
          if (preference != null &&
              liveWait != null &&
              !preference.waitTolerance.allows(liveWait.waitMinutes)) {
            warnings.add(
              '${facility.name}は待ち時間${liveWait.waitMinutes}分が許容範囲を超えたため後回し候補から除外しました。',
            );
            return false;
          }
          return true;
        })
        .toList(growable: false);

    final eligibleIds = eligibleFacilities
        .map((facility) => facility.id)
        .toSet();
    final eligiblePreferences = request.preferences
        .where((preference) => eligibleIds.contains(preference.facilityId))
        .toList(growable: false);

    final generated = scheduleEngine.generate(
      settings: request.settings,
      facilities: eligibleFacilities,
      preferences: eligiblePreferences,
    );

    final preservedKeys = preserved.map(_key).toSet();
    final futureGenerated = generated.items.where((item) {
      if (item.type == ScheduleItemType.entry ||
          item.type == ScheduleItemType.exit) {
        return false;
      }
      return _start(item) > nowMinutes && !preservedKeys.contains(_key(item));
    });

    final exitItem = request.currentSchedule.items
        .where((item) => item.type == ScheduleItemType.exit)
        .cast<ScheduleItem?>()
        .firstOrNull;

    final merged = <ScheduleItem>[
      ...preserved.where((item) => item.type != ScheduleItemType.exit),
      ...futureGenerated,
      ?exitItem,
    ]..sort((a, b) => _start(a).compareTo(_start(b)));

    final after = DaySchedule(
      id: 'schedule_${DateTime.now().millisecondsSinceEpoch}',
      parkId: request.currentSchedule.parkId,
      items: List<ScheduleItem>.unmodifiable(merged),
      createdAt: DateTime.now(),
    );

    return ScheduleRecalculationResult(
      beforeSchedule: request.currentSchedule,
      afterSchedule: after,
      preservedItems: List<ScheduleItem>.unmodifiable(preserved),
      changes: List<ScheduleChange>.unmodifiable(
        _buildChanges(request.currentSchedule, after, preservedKeys),
      ),
      warnings: List<String>.unmodifiable(warnings),
      createdAt: DateTime.now(),
    );
  }

  List<ScheduleChange> _buildChanges(
    DaySchedule before,
    DaySchedule after,
    Set<String> preservedKeys,
  ) {
    final beforeByKey = {for (final item in before.items) _key(item): item};
    final afterByKey = {for (final item in after.items) _key(item): item};
    final keys = {...beforeByKey.keys, ...afterByKey.keys}.toList()..sort();
    final changes = <ScheduleChange>[];

    for (final key in keys) {
      final oldItem = beforeByKey[key];
      final newItem = afterByKey[key];
      if (oldItem == null && newItem != null) {
        changes.add(
          ScheduleChange(
            key: key,
            type: ScheduleChangeType.added,
            reason: '残り時間へ新たに配置しました。',
            afterItem: newItem,
          ),
        );
      } else if (oldItem != null && newItem == null) {
        changes.add(
          ScheduleChange(
            key: key,
            type: ScheduleChangeType.removed,
            reason: '営業状態・待ち時間・時間不足のいずれかにより配置できませんでした。',
            beforeItem: oldItem,
          ),
        );
      } else if (oldItem != null && newItem != null) {
        final moved =
            _start(oldItem) != _start(newItem) ||
            _end(oldItem) != _end(newItem);
        changes.add(
          ScheduleChange(
            key: key,
            type: moved
                ? ScheduleChangeType.moved
                : ScheduleChangeType.unchanged,
            reason: preservedKeys.contains(key)
                ? '完了済み・進行中・確定固定予定として維持しました。'
                : moved
                ? '残り予定を再配置しました。'
                : '変更はありません。',
            beforeItem: oldItem,
            afterItem: newItem,
          ),
        );
      }
    }
    return changes;
  }

  int _start(ScheduleItem item) => item.startHour * 60 + item.startMinute;
  int _end(ScheduleItem item) => item.endHour * 60 + item.endMinute;
  String _key(ScheduleItem item) =>
      item.facilityId ?? '${item.type.name}:${item.id}';
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
