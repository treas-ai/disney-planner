import '../entities/facility.dart';
import '../entities/plan_preference.dart';
import '../enums/fixed_time_status.dart';

class FixedScheduleConflictService {
  const FixedScheduleConflictService();

  List<String> findConflicts({
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
  }) {
    final preferenceById = {
      for (final preference in preferences) preference.facilityId: preference,
    };
    final windows = <_FixedWindow>[];

    for (final facility in facilities) {
      final preference = preferenceById[facility.id];
      if (preference == null ||
          preference.fixedTimeStatus != FixedTimeStatus.confirmed) {
        continue;
      }
      final reservation = _parse(preference.reservationTime);
      final performance = _parse(preference.preferredPerformanceTime);
      final access = _parse(preference.scheduledAccessTime);
      final anchor = performance ?? reservation ?? access;
      if (anchor == null) continue;

      final isParkExitReservation =
          reservation != null && facility.requiresParkExit;
      final start = isParkExitReservation
          ? anchor - facility.outboundTravelMinutes
          : anchor;
      final end = isParkExitReservation
          ? anchor + facility.durationMinutes + facility.returnTravelMinutes
          : anchor + facility.durationMinutes;
      windows.add(
        _FixedWindow(
          facility: facility,
          start: start,
          end: end,
          anchor: anchor,
          isParkExitReservation: isParkExitReservation,
        ),
      );
    }

    windows.sort((a, b) => a.start.compareTo(b.start));
    final conflicts = <String>[];
    for (var i = 0; i < windows.length; i++) {
      for (var j = i + 1; j < windows.length; j++) {
        final left = windows[i];
        final right = windows[j];
        if (right.start >= left.end) break;
        if (right.start < left.end && right.end > left.start) {
          conflicts.add(
            '${_describe(left)} と ${_describe(right)} は両立できません。',
          );
        }
      }
    }
    return List<String>.unmodifiable(conflicts);
  }

  String _describe(_FixedWindow window) {
    if (window.isParkExitReservation) {
      return '${window.facility.name}（予約${_format(window.anchor)}、外出${_format(window.start)}-${_format(window.end)}）';
    }
    return '${window.facility.name}（${_format(window.start)}-${_format(window.end)}）';
  }

  int? _parse(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  String _format(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

class _FixedWindow {
  const _FixedWindow({
    required this.facility,
    required this.start,
    required this.end,
    required this.anchor,
    required this.isParkExitReservation,
  });

  final Facility facility;
  final int start;
  final int end;
  final int anchor;
  final bool isParkExitReservation;
}
