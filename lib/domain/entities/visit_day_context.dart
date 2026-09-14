class VisitDayContext {
  const VisitDayContext({
    required this.date,
    required this.isNationalHoliday,
    this.nationalHolidayName,
    this.regionalEventIds = const [],
    this.regionalEventNames = const [],
    this.specialEventIds = const [],
    this.specialEventNames = const [],
  });

  final DateTime date;
  final bool isNationalHoliday;
  final String? nationalHolidayName;
  final List<String> regionalEventIds;
  final List<String> regionalEventNames;
  final List<String> specialEventIds;
  final List<String> specialEventNames;

  List<String> get eventIds => List<String>.unmodifiable([
        ...regionalEventIds,
        ...specialEventIds,
      ]);

  bool get hasSpecialContext =>
      isNationalHoliday || eventIds.isNotEmpty;

  List<String> factorDimensionKeys() => List<String>.unmodifiable([
        'weekday:${date.weekday}',
        'season:${_season(date.month)}',
        if (isNationalHoliday) 'holiday:true',
        ...eventIds.map((id) => 'event:$id'),
      ]);

  String get summary {
    final labels = <String>[
      ...<String?>[nationalHolidayName].whereType<String>(),
      ...regionalEventNames,
      ...specialEventNames,
    ];
    return labels.join('・');
  }

  static String _season(int month) {
    if (month == 12 || month <= 2) return 'winter';
    if (month <= 5) return 'spring';
    if (month <= 8) return 'summer';
    return 'autumn';
  }
}

class VisitDayRuleSet {
  const VisitDayRuleSet._({
    required this._nationalHolidays,
    required this._regionalDays,
    required this._specialDays,
  });

  factory VisitDayRuleSet.fromJson(Map<String, dynamic> json) {
    return VisitDayRuleSet._(
      nationalHolidays: List<_DatedVisitDayRule>.unmodifiable(
        (json['nationalHolidays'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(_DatedVisitDayRule.fromJson),
      ),
      regionalDays: List<_RecurringVisitDayRule>.unmodifiable(
        (json['regionalDays'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(_RecurringVisitDayRule.fromJson),
      ),
      specialDays: List<_DatedVisitDayRule>.unmodifiable(
        (json['specialDays'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(_DatedVisitDayRule.fromJson),
      ),
    );
  }

  final List<_DatedVisitDayRule> _nationalHolidays;
  final List<_RecurringVisitDayRule> _regionalDays;
  final List<_DatedVisitDayRule> _specialDays;

  VisitDayContext contextFor(DateTime date) {
    final localDate = DateTime(date.year, date.month, date.day);
    _DatedVisitDayRule? holiday;
    for (final rule in _nationalHolidays) {
      if (rule.matches(localDate)) {
        holiday = rule;
        break;
      }
    }

    final regionalMatches = _regionalDays
        .where((rule) => rule.matches(localDate))
        .toList(growable: false);
    final specialMatches = _specialDays
        .where((rule) => rule.matches(localDate))
        .toList(growable: false);
    final longWeekend = _longWeekendContext(localDate);

    return VisitDayContext(
      date: localDate,
      isNationalHoliday: holiday != null,
      nationalHolidayName: holiday?.name,
      regionalEventIds:
          regionalMatches.map((rule) => rule.id).toList(growable: false),
      regionalEventNames:
          regionalMatches.map((rule) => rule.name).toList(growable: false),
      specialEventIds: List<String>.unmodifiable([
        ...specialMatches.map((rule) => rule.id),
        ...longWeekend.ids,
      ]),
      specialEventNames: List<String>.unmodifiable([
        ...specialMatches.map((rule) => rule.name),
        ...longWeekend.names,
      ]),
    );
  }

  ({List<String> ids, List<String> names}) _longWeekendContext(
    DateTime date,
  ) {
    if (!_isNonWorkDay(date)) {
      return (ids: const [], names: const []);
    }

    var start = date;
    var end = date;
    for (var i = 0; i < 7; i++) {
      final previous = start.subtract(const Duration(days: 1));
      if (!_isNonWorkDay(previous)) break;
      start = previous;
    }
    for (var i = 0; i < 7; i++) {
      final next = end.add(const Duration(days: 1));
      if (!_isNonWorkDay(next)) break;
      end = next;
    }

    final length = end.difference(start).inDays + 1;
    if (length < 3) {
      return (ids: const [], names: const []);
    }

    final position = date == start
        ? 'start'
        : date == end
            ? 'final'
            : 'middle';
    final positionName = switch (position) {
      'start' => '連休初日',
      'final' => '連休最終日',
      _ => '連休中日',
    };
    return (
      ids: ['long_weekend_3plus', 'long_weekend_$position'],
      names: ['$length日連休', positionName],
    );
  }

  bool _isNonWorkDay(DateTime date) {
    if (date.weekday == DateTime.saturday ||
        date.weekday == DateTime.sunday) {
      return true;
    }
    for (final rule in _nationalHolidays) {
      if (rule.matches(date)) return true;
    }
    return false;
  }
}

class _DatedVisitDayRule {
  const _DatedVisitDayRule({
    required this.id,
    required this.name,
    required this.date,
  });

  factory _DatedVisitDayRule.fromJson(Map<String, dynamic> json) {
    return _DatedVisitDayRule(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime(2000),
    );
  }

  final String id;
  final String name;
  final DateTime date;

  bool matches(DateTime target) =>
      date.year == target.year &&
      date.month == target.month &&
      date.day == target.day;
}

class _RecurringVisitDayRule {
  const _RecurringVisitDayRule({
    required this.id,
    required this.name,
    required this.month,
    required this.day,
  });

  factory _RecurringVisitDayRule.fromJson(Map<String, dynamic> json) {
    final parts = (json['monthDay']?.toString() ?? '').split('-');
    return _RecurringVisitDayRule(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      month: parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      day: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  final String id;
  final String name;
  final int month;
  final int day;

  bool matches(DateTime target) => target.month == month && target.day == day;
}
