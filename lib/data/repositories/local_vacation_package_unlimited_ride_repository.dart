import 'dart:convert';

import 'package:flutter/services.dart';

class LocalVacationPackageUnlimitedRideRepository {
  const LocalVacationPackageUnlimitedRideRepository();

  static const String _assetPath =
      'assets/master/vacation_package_unlimited_rides.json';

  Future<Map<String, int>> loadPriorityAccessBufferMinutes({
    required String parkId,
  }) async {
    final raw = await rootBundle.loadString(_assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final planning = json['planning'] as Map<String, dynamic>? ?? const {};
    final defaultBuffer =
        (planning['defaultPriorityAccessBufferMinutes'] as num?)?.toInt() ?? 15;
    final parks = json['parks'] as Map<String, dynamic>? ?? const {};
    final entries = parks[parkId] as List<dynamic>? ?? const [];

    final result = <String, int>{};
    for (final entry in entries) {
      if (entry is String) {
        // schemaVersion 1 compatibility.
        result[entry] = defaultBuffer;
        continue;
      }
      if (entry is! Map<String, dynamic>) continue;
      final facilityId = entry['facilityId'] as String?;
      if (facilityId == null || facilityId.isEmpty) continue;
      final buffer =
          (entry['priorityAccessBufferMinutes'] as num?)?.toInt() ??
              defaultBuffer;
      result[facilityId] = buffer.clamp(0, 60).toInt();
    }
    return result;
  }

  Future<Set<String>> loadFacilityIds({required String parkId}) async {
    final buffers = await loadPriorityAccessBufferMinutes(parkId: parkId);
    return buffers.keys.toSet();
  }
}
