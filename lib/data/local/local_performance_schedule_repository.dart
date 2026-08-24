import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/performance_time_option.dart';
import '../../domain/repositories/performance_schedule_repository.dart';

class LocalPerformanceScheduleRepository
    implements PerformanceScheduleRepository {
  LocalPerformanceScheduleRepository({
    this.assetPath = 'assets/master/performance_schedules.json',
  });

  final String assetPath;
  List<PerformanceTimeOption>? _cache;

  @override
  Future<List<PerformanceTimeOption>> findOptions({
    required String parkId,
    required String facilityId,
    required DateTime date,
  }) async {
    final allOptions = await _load();
    final dateKey = _dateKey(date);

    final result =
        allOptions
            .where((option) {
              return option.parkId == parkId &&
                  option.facilityId == facilityId &&
                  _dateKey(option.date) == dateKey;
            })
            .toList(growable: false)
          ..sort((left, right) {
            final byIndex = left.performanceIndex.compareTo(
              right.performanceIndex,
            );
            if (byIndex != 0) {
              return byIndex;
            }
            return left.startTime.compareTo(right.startTime);
          });

    return List<PerformanceTimeOption>.unmodifiable(result);
  }


  @override
  Future<List<PerformanceTimeOption>> findParkOptions({
    required String parkId,
    required DateTime date,
  }) async {
    final allOptions = await _load();
    final dateKey = _dateKey(date);

    final result = allOptions
        .where((option) {
          return option.parkId == parkId && _dateKey(option.date) == dateKey;
        })
        .toList(growable: false)
      ..sort((left, right) {
        final byTime = left.startTime.compareTo(right.startTime);
        if (byTime != 0) return byTime;
        return left.performanceIndex.compareTo(right.performanceIndex);
      });

    return List<PerformanceTimeOption>.unmodifiable(result);
  }

  Future<List<PerformanceTimeOption>> _load() async {
    final cached = _cache;
    if (cached != null) {
      return cached;
    }

    final source = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(source);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'performance_schedules.jsonのルートはJSONオブジェクトである必要があります。',
      );
    }

    final rawSchedules = decoded['schedules'];
    if (rawSchedules is! List) {
      throw const FormatException(
        'performance_schedules.jsonにschedules配列がありません。',
      );
    }

    final options = <PerformanceTimeOption>[];

    for (final rawSchedule in rawSchedules) {
      if (rawSchedule is! Map) {
        continue;
      }

      final schedule = <String, dynamic>{};
      for (final entry in rawSchedule.entries) {
        schedule[entry.key.toString()] = entry.value;
      }

      final option = PerformanceTimeOption.fromJson(schedule);
      if (_isValid(option)) {
        options.add(option);
      }
    }

    _cache = List<PerformanceTimeOption>.unmodifiable(options);
    return _cache!;
  }

  bool _isValid(PerformanceTimeOption option) {
    return option.id.trim().isNotEmpty &&
        option.parkId.trim().isNotEmpty &&
        option.facilityId.trim().isNotEmpty &&
        option.date.millisecondsSinceEpoch > 0 &&
        option.performanceIndex >= 0 &&
        RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(option.startTime);
  }

  String _dateKey(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
