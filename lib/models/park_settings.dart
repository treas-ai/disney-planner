class ParkSettings {
  final String park;
  final String entryTime;
  final String leaveTime;
  final int people;
  final bool happyEntry;
  final bool useDpa;
  final bool usePriorityPass;
  final bool useSingleRider;
  final bool lunch;
  final bool dinner;
  final bool rainMode;
  final bool hasChildren;

  const ParkSettings({
    required this.park,
    required this.entryTime,
    required this.leaveTime,
    required this.people,
    required this.happyEntry,
    required this.useDpa,
    required this.usePriorityPass,
    required this.useSingleRider,
    required this.lunch,
    required this.dinner,
    required this.rainMode,
    required this.hasChildren,
  });

  Map<String, dynamic> toJson() {
    return {
      'park': park,
      'entryTime': entryTime,
      'leaveTime': leaveTime,
      'people': people,
      'happyEntry': happyEntry,
      'useDpa': useDpa,
      'usePriorityPass': usePriorityPass,
      'useSingleRider': useSingleRider,
      'lunch': lunch,
      'dinner': dinner,
      'rainMode': rainMode,
      'hasChildren': hasChildren,
    };
  }

  factory ParkSettings.fromJson(Map<String, dynamic> json) {
    return ParkSettings(
      park: json['park'] ?? '東京ディズニーランド',
      entryTime: json['entryTime'] ?? '09:00',
      leaveTime: json['leaveTime'] ?? '21:00',
      people: json['people'] ?? 2,
      happyEntry: json['happyEntry'] ?? false,
      useDpa: json['useDpa'] ?? false,
      usePriorityPass: json['usePriorityPass'] ?? true,
      useSingleRider: json['useSingleRider'] ?? false,
      lunch: json['lunch'] ?? true,
      dinner: json['dinner'] ?? true,
      rainMode: json['rainMode'] ?? false,
      hasChildren: json['hasChildren'] ?? false,
    );
  }
}