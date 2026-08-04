import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/data_freshness_info.dart';

class DataFreshnessService {
  const DataFreshnessService();

  Future<DataFreshnessInfo> loadPerformanceScheduleInfo() async {
    final raw = await rootBundle.loadString(
      'assets/master/performance_schedules.json',
    );
    final decoded = jsonDecode(raw);
    final map = decoded is Map ? decoded : const {};
    final updatedAt = DateTime.tryParse(map['updatedAt']?.toString() ?? '');
    return DataFreshnessInfo(
      label: 'ショー・パレード公演時刻',
      updatedAt: updatedAt,
      note: map['sourceNote']?.toString() ?? '公式情報確認日を表示します。',
    );
  }
}
