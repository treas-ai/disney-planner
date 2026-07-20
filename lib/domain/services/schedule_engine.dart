import '../entities/day_schedule.dart';
import '../entities/facility.dart';
import '../entities/plan_preference.dart';
import '../entities/schedule_item.dart';
import '../entities/trip_settings.dart';
import '../enums/preferred_time.dart';
import '../enums/schedule_item_type.dart';

class ScheduleEngine {
  const ScheduleEngine();

  DaySchedule generate({
    required TripSettings settings,
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
  }) {
    final items = <ScheduleItem>[];

    var currentHour = settings.entryTimeHour;
    var currentMinute = settings.entryTimeMinute;

    items.add(
      ScheduleItem(
        id: 'entry',
        title: '入園',
        type: ScheduleItemType.entry,
        startHour: currentHour,
        startMinute: currentMinute,
        endHour: currentHour,
        endMinute: currentMinute + 15,
        reason: '設定された入園時間です。',
      ),
    );

    currentMinute += 15;
    final normalizedEntryTime = _normalizeTime(currentHour, currentMinute);
    currentHour = normalizedEntryTime.hour;
    currentMinute = normalizedEntryTime.minute;

    final sortedFacilities = _sortFacilitiesByPreference(
      facilities: facilities,
      preferences: preferences,
    );

    var lunchInserted = false;
    var dinnerInserted = false;

    for (final facility in sortedFacilities) {
      if (settings.wantsLunch && !lunchInserted && currentHour >= 12) {
        final lunch = _createMealItem(
          id: 'lunch',
          title: '昼食',
          type: ScheduleItemType.lunch,
          startHour: currentHour,
          startMinute: currentMinute,
          reason: '昼食ありの設定のため追加しました。',
        );

        items.add(lunch);
        final next = _addMinutes(currentHour, currentMinute, 60);
        currentHour = next.hour;
        currentMinute = next.minute;
        lunchInserted = true;
      }

      if (settings.wantsDinner && !dinnerInserted && currentHour >= 18) {
        final dinner = _createMealItem(
          id: 'dinner',
          title: '夕食',
          type: ScheduleItemType.dinner,
          startHour: currentHour,
          startMinute: currentMinute,
          reason: '夕食ありの設定のため追加しました。',
        );

        items.add(dinner);
        final next = _addMinutes(currentHour, currentMinute, 60);
        currentHour = next.hour;
        currentMinute = next.minute;
        dinnerInserted = true;
      }

      final preference = _findPreference(
        facilityId: facility.id,
        preferences: preferences,
      );

      final startHour = currentHour;
      final startMinute = currentMinute;
      final end = _addMinutes(startHour, startMinute, 60);

      items.add(
        ScheduleItem(
          id: 'schedule_${facility.id}',
          title: facility.name,
          type: ScheduleItemType.facility,
          facilityId: facility.id,
          startHour: startHour,
          startMinute: startMinute,
          endHour: end.hour,
          endMinute: end.minute,
          reason: _buildReason(preference),
          note: facility.description,
        ),
      );

      final next = _addMinutes(end.hour, end.minute, 15);
      currentHour = next.hour;
      currentMinute = next.minute;
    }

    if (settings.wantsLunch && !lunchInserted) {
      items.add(
        _createMealItem(
          id: 'lunch',
          title: '昼食',
          type: ScheduleItemType.lunch,
          startHour: 12,
          startMinute: 0,
          reason: '昼食ありの設定のため追加しました。',
        ),
      );
    }

    if (settings.wantsDinner && !dinnerInserted) {
      items.add(
        _createMealItem(
          id: 'dinner',
          title: '夕食',
          type: ScheduleItemType.dinner,
          startHour: 18,
          startMinute: 0,
          reason: '夕食ありの設定のため追加しました。',
        ),
      );
    }

    items.add(
      ScheduleItem(
        id: 'exit',
        title: '退園',
        type: ScheduleItemType.exit,
        startHour: settings.exitTimeHour,
        startMinute: settings.exitTimeMinute,
        endHour: settings.exitTimeHour,
        endMinute: settings.exitTimeMinute,
        reason: '設定された退園時間です。',
      ),
    );

    items.sort((a, b) {
      final aMinutes = a.startHour * 60 + a.startMinute;
      final bMinutes = b.startHour * 60 + b.startMinute;
      return aMinutes.compareTo(bMinutes);
    });

    return DaySchedule(
      id: 'schedule_${DateTime.now().millisecondsSinceEpoch}',
      parkId: settings.parkId,
      items: items,
      createdAt: DateTime.now(),
    );
  }

  List<Facility> _sortFacilitiesByPreference({
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
  }) {
    final sortedFacilities = List<Facility>.from(facilities);

    sortedFacilities.sort((a, b) {
      final aPreference = _findPreference(
        facilityId: a.id,
        preferences: preferences,
      );
      final bPreference = _findPreference(
        facilityId: b.id,
        preferences: preferences,
      );

      final aPriority = aPreference?.priority.value ?? a.priority.value;
      final bPriority = bPreference?.priority.value ?? b.priority.value;

      final priorityCompare = bPriority.compareTo(aPriority);

      if (priorityCompare != 0) {
        return priorityCompare;
      }

      final aTimeScore = _preferredTimeScore(aPreference?.preferredTime);
      final bTimeScore = _preferredTimeScore(bPreference?.preferredTime);

      return aTimeScore.compareTo(bTimeScore);
    });

    return sortedFacilities;
  }

  int _preferredTimeScore(PreferredTime? preferredTime) {
    switch (preferredTime) {
      case PreferredTime.morning:
        return 0;
      case PreferredTime.afternoon:
        return 1;
      case PreferredTime.evening:
        return 2;
      case PreferredTime.anytime:
      case null:
        return 3;
    }
  }

  PlanPreference? _findPreference({
    required String facilityId,
    required List<PlanPreference> preferences,
  }) {
    for (final preference in preferences) {
      if (preference.facilityId == facilityId) {
        return preference;
      }
    }

    return null;
  }

  String _buildReason(PlanPreference? preference) {
    if (preference == null) {
      return '施設の基本優先度をもとに配置しました。';
    }

    return '優先度「${preference.priority.label}」、希望時間「${preference.preferredTime.label}」を考慮しました。';
  }

  ScheduleItem _createMealItem({
    required String id,
    required String title,
    required ScheduleItemType type,
    required int startHour,
    required int startMinute,
    required String reason,
  }) {
    final end = _addMinutes(startHour, startMinute, 60);

    return ScheduleItem(
      id: id,
      title: title,
      type: type,
      startHour: startHour,
      startMinute: startMinute,
      endHour: end.hour,
      endMinute: end.minute,
      reason: reason,
    );
  }

  _ScheduleTime _addMinutes(int hour, int minute, int additionalMinutes) {
    final totalMinutes = hour * 60 + minute + additionalMinutes;

    return _ScheduleTime(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
  }

  _ScheduleTime _normalizeTime(int hour, int minute) {
    final totalMinutes = hour * 60 + minute;

    return _ScheduleTime(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
  }
}

class _ScheduleTime {
  const _ScheduleTime({required this.hour, required this.minute});

  final int hour;
  final int minute;
}
