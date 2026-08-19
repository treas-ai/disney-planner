import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/dpa_sellout_profile.dart';

class JsonDpaSelloutDataSource {
  const JsonDpaSelloutDataSource();

  Future<List<DpaSelloutProfile>> load({required String parkId}) async {
    final raw = await rootBundle.loadString(
      'assets/master/dpa_sellout/$parkId.json',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(DpaSelloutProfile.fromJson)
        .toList(growable: false);
  }
}
