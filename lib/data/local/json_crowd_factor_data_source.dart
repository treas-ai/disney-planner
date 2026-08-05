import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/crowd_factor_profile.dart';
import '../../domain/entities/time_band_wait_profile.dart';

class JsonCrowdFactorDataSource {
  const JsonCrowdFactorDataSource();

  Future<List<CrowdFactorProfile>> loadCrowdFactors({
    required String parkId,
  }) async {
    final raw = await rootBundle.loadString(
      'assets/master/crowd_factors/$parkId.json',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(CrowdFactorProfile.fromJson)
        .toList(growable: false);
  }

  Future<List<TimeBandWaitProfile>> loadWaitProfiles({
    required String parkId,
  }) async {
    final raw = await rootBundle.loadString(
      'assets/master/wait_profiles/$parkId.json',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(TimeBandWaitProfile.fromJson)
        .toList(growable: false);
  }
}
