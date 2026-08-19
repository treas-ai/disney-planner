import '../../domain/enums/live_operation_availability.dart';

class ThemeParksWikiLiveEntry {
  const ThemeParksWikiLiveEntry({
    required this.sourceEntityId,
    required this.name,
    required this.entityType,
    required this.availability,
    required this.updatedAt,
    this.standbyMinutes,
    this.singleRiderMinutes,
    this.paidReturnState,
    this.paidReturnStart,
    this.paidReturnEnd,
    this.showtimes = const [],
  });

  final String sourceEntityId;
  final String name;
  final String entityType;
  final LiveOperationAvailability availability;
  final DateTime updatedAt;
  final int? standbyMinutes;
  final int? singleRiderMinutes;
  final String? paidReturnState;
  final String? paidReturnStart;
  final String? paidReturnEnd;
  final List<Map<String, dynamic>> showtimes;

  bool? get paidReturnAvailable {
    final state = paidReturnState?.toUpperCase();
    if (state == null) return null;
    if (state == 'AVAILABLE') return true;
    if (state == 'FINISHED' || state == 'CLOSED' || state == 'UNAVAILABLE') {
      return false;
    }
    return null;
  }
}

class ThemeParksWikiLiveParser {
  const ThemeParksWikiLiveParser();

  List<ThemeParksWikiLiveEntry> parse(Map<String, dynamic> json) {
    final rows = json['liveData'] as List<dynamic>? ?? const [];
    return rows.whereType<Map<String, dynamic>>().map(_parseEntry).toList();
  }

  ThemeParksWikiLiveEntry _parseEntry(Map<String, dynamic> row) {
    final rawQueue = row['queue'];
    final queue = rawQueue is Map
        ? Map<String, dynamic>.from(rawQueue)
        : <String, dynamic>{};
    final standby = _stringMap(queue['STANDBY']);
    final single = _stringMap(queue['SINGLE_RIDER']);
    final paid = _stringMap(queue['PAID_RETURN_TIME']);
    final rawShows = row['showtimes'] as List<dynamic>? ?? const [];
    return ThemeParksWikiLiveEntry(
      sourceEntityId: row['id']?.toString() ?? row['entityId']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      entityType: row['entityType']?.toString() ?? '',
      availability: _availability(row['status']?.toString()),
      updatedAt: DateTime.tryParse(row['lastUpdated']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      standbyMinutes: _intValue(standby?['waitTime']),
      singleRiderMinutes: _intValue(single?['waitTime']),
      paidReturnState: paid?['state']?.toString(),
      paidReturnStart: paid?['returnStart']?.toString(),
      paidReturnEnd: paid?['returnEnd']?.toString(),
      showtimes: rawShows.whereType<Map<String, dynamic>>().toList(growable: false),
    );
  }

  LiveOperationAvailability _availability(String? value) =>
      switch (value?.toUpperCase()) {
        'OPERATING' => LiveOperationAvailability.operating,
        'DOWN' => LiveOperationAvailability.temporarilySuspended,
        'REFURBISHMENT' => LiveOperationAvailability.systemAdjustment,
        'CLOSED' => LiveOperationAvailability.closed,
        _ => LiveOperationAvailability.unknown,
      };

  Map<String, dynamic>? _stringMap(Object? value) {
    if (value is! Map) return null;
    return Map<String, dynamic>.from(value);
  }

  int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }
}
