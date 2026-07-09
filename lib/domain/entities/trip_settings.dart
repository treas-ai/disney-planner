class TripSettings {
  const TripSettings({
    required this.parkId,
    required this.entryTimeHour,
    required this.entryTimeMinute,
    required this.exitTimeHour,
    required this.exitTimeMinute,
    required this.numberOfPeople,
    required this.hasHappyEntry,
    required this.canUseDpa,
    required this.canUsePriorityPass,
    required this.canUseSingleRider,
    required this.wantsLunch,
    required this.wantsDinner,
    required this.isRainy,
    required this.hasChildren,
  });

  factory TripSettings.initial() {
    return const TripSettings(
      parkId: 'tokyo_disneysea',
      entryTimeHour: 9,
      entryTimeMinute: 0,
      exitTimeHour: 21,
      exitTimeMinute: 0,
      numberOfPeople: 1,
      hasHappyEntry: false,
      canUseDpa: true,
      canUsePriorityPass: true,
      canUseSingleRider: false,
      wantsLunch: true,
      wantsDinner: true,
      isRainy: false,
      hasChildren: false,
    );
  }

  final String parkId;

  final int entryTimeHour;
  final int entryTimeMinute;

  final int exitTimeHour;
  final int exitTimeMinute;

  final int numberOfPeople;

  final bool hasHappyEntry;
  final bool canUseDpa;
  final bool canUsePriorityPass;
  final bool canUseSingleRider;

  final bool wantsLunch;
  final bool wantsDinner;

  final bool isRainy;
  final bool hasChildren;

  String get entryTimeLabel {
    return '${entryTimeHour.toString().padLeft(2, '0')}:'
        '${entryTimeMinute.toString().padLeft(2, '0')}';
  }

  String get exitTimeLabel {
    return '${exitTimeHour.toString().padLeft(2, '0')}:'
        '${exitTimeMinute.toString().padLeft(2, '0')}';
  }

  TripSettings copyWith({
    String? parkId,
    int? entryTimeHour,
    int? entryTimeMinute,
    int? exitTimeHour,
    int? exitTimeMinute,
    int? numberOfPeople,
    bool? hasHappyEntry,
    bool? canUseDpa,
    bool? canUsePriorityPass,
    bool? canUseSingleRider,
    bool? wantsLunch,
    bool? wantsDinner,
    bool? isRainy,
    bool? hasChildren,
  }) {
    return TripSettings(
      parkId: parkId ?? this.parkId,
      entryTimeHour: entryTimeHour ?? this.entryTimeHour,
      entryTimeMinute: entryTimeMinute ?? this.entryTimeMinute,
      exitTimeHour: exitTimeHour ?? this.exitTimeHour,
      exitTimeMinute: exitTimeMinute ?? this.exitTimeMinute,
      numberOfPeople: numberOfPeople ?? this.numberOfPeople,
      hasHappyEntry: hasHappyEntry ?? this.hasHappyEntry,
      canUseDpa: canUseDpa ?? this.canUseDpa,
      canUsePriorityPass: canUsePriorityPass ?? this.canUsePriorityPass,
      canUseSingleRider: canUseSingleRider ?? this.canUseSingleRider,
      wantsLunch: wantsLunch ?? this.wantsLunch,
      wantsDinner: wantsDinner ?? this.wantsDinner,
      isRainy: isRainy ?? this.isRainy,
      hasChildren: hasChildren ?? this.hasChildren,
    );
  }
}