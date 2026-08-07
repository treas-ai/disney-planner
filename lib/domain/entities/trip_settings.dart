class TripSettings {
  const TripSettings({
    required this.parkId,
    this.visitDateIso = '',
    required this.entryTimeHour,
    required this.entryTimeMinute,
    this.queueArrivalTimeHour = 7,
    this.queueArrivalTimeMinute = 0,
    this.happyEntryTimeHour = 8,
    this.happyEntryTimeMinute = 45,
    required this.exitTimeHour,
    required this.exitTimeMinute,
    required this.numberOfPeople,
    required this.hasHappyEntry,
    required this.canUseDpa,
    required this.canUsePriorityPass,
    required this.canUseSingleRider,
    required this.usesVacationPackage,
    required this.usesFreeDrinkBenefit,
    required this.hasAttractionVoucher,
    required this.hasShowVoucher,
    required this.hasRestaurantReservation,
    required this.wantsBreakfast,
    required this.wantsLunch,
    required this.wantsDinner,
    required this.isRainy,
    required this.hasChildren,
  });

  factory TripSettings.initial() => const TripSettings(
    parkId: 'tokyo_disneysea',
    visitDateIso: '',
    entryTimeHour: 9,
    entryTimeMinute: 0,
    queueArrivalTimeHour: 7,
    queueArrivalTimeMinute: 0,
    happyEntryTimeHour: 8,
    happyEntryTimeMinute: 45,
    exitTimeHour: 21,
    exitTimeMinute: 0,
    numberOfPeople: 1,
    hasHappyEntry: false,
    canUseDpa: true,
    canUsePriorityPass: true,
    canUseSingleRider: false,
    usesVacationPackage: false,
    usesFreeDrinkBenefit: false,
    hasAttractionVoucher: false,
    hasShowVoucher: false,
    hasRestaurantReservation: false,
    wantsBreakfast: false,
    wantsLunch: true,
    wantsDinner: true,
    isRainy: false,
    hasChildren: false,
  );

  factory TripSettings.fromJson(Map<String, dynamic> json) => TripSettings(
    parkId: json['parkId'] as String? ?? 'tokyo_disneysea',
    visitDateIso: json['visitDateIso'] as String? ?? '',
    entryTimeHour: json['entryTimeHour'] as int? ?? 9,
    entryTimeMinute: json['entryTimeMinute'] as int? ?? 0,
    queueArrivalTimeHour: json['queueArrivalTimeHour'] as int? ?? 7,
    queueArrivalTimeMinute: json['queueArrivalTimeMinute'] as int? ?? 0,
    happyEntryTimeHour: json['happyEntryTimeHour'] as int? ?? 8,
    happyEntryTimeMinute: json['happyEntryTimeMinute'] as int? ?? 45,
    exitTimeHour: json['exitTimeHour'] as int? ?? 21,
    exitTimeMinute: json['exitTimeMinute'] as int? ?? 0,
    numberOfPeople: json['numberOfPeople'] as int? ?? 1,
    hasHappyEntry: json['hasHappyEntry'] as bool? ?? false,
    canUseDpa: json['canUseDpa'] as bool? ?? true,
    canUsePriorityPass: json['canUsePriorityPass'] as bool? ?? true,
    canUseSingleRider: json['canUseSingleRider'] as bool? ?? false,
    usesVacationPackage: json['usesVacationPackage'] as bool? ?? false,
    usesFreeDrinkBenefit: json['usesFreeDrinkBenefit'] as bool? ?? false,
    hasAttractionVoucher: json['hasAttractionVoucher'] as bool? ?? false,
    hasShowVoucher: json['hasShowVoucher'] as bool? ?? false,
    hasRestaurantReservation:
        json['hasRestaurantReservation'] as bool? ?? false,
    wantsBreakfast: json['wantsBreakfast'] as bool? ?? false,
    wantsLunch: json['wantsLunch'] as bool? ?? true,
    wantsDinner: json['wantsDinner'] as bool? ?? true,
    isRainy: json['isRainy'] as bool? ?? false,
    hasChildren: json['hasChildren'] as bool? ?? false,
  );

  final String parkId;
  final String visitDateIso;
  final int entryTimeHour;
  final int entryTimeMinute;
  final int queueArrivalTimeHour;
  final int queueArrivalTimeMinute;
  final int happyEntryTimeHour;
  final int happyEntryTimeMinute;
  final int exitTimeHour;
  final int exitTimeMinute;
  final int numberOfPeople;
  final bool hasHappyEntry;
  final bool canUseDpa;
  final bool canUsePriorityPass;
  final bool canUseSingleRider;
  final bool usesVacationPackage;
  final bool usesFreeDrinkBenefit;
  final bool hasAttractionVoucher;
  final bool hasShowVoucher;
  final bool hasRestaurantReservation;
  final bool wantsBreakfast;
  final bool wantsLunch;
  final bool wantsDinner;
  final bool isRainy;
  final bool hasChildren;

  DateTime? get visitDate {
    if (visitDateIso.isEmpty) return null;
    return DateTime.tryParse(visitDateIso);
  }

  String get visitDateLabel {
    final date = visitDate;
    if (date == null) return '来園日未設定';
    return '${date.month}/${date.day}';
  }

  String get entryTimeLabel =>
      '${entryTimeHour.toString().padLeft(2, '0')}:'
      '${entryTimeMinute.toString().padLeft(2, '0')}';
  String get officialOpeningTimeLabel => entryTimeLabel;
  String get queueArrivalTimeLabel =>
      '${queueArrivalTimeHour.toString().padLeft(2, '0')}:'
      '${queueArrivalTimeMinute.toString().padLeft(2, '0')}';
  String get happyEntryTimeLabel =>
      '${happyEntryTimeHour.toString().padLeft(2, '0')}:'
      '${happyEntryTimeMinute.toString().padLeft(2, '0')}';
  String get exitTimeLabel =>
      '${exitTimeHour.toString().padLeft(2, '0')}:'
      '${exitTimeMinute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'parkId': parkId,
    'visitDateIso': visitDateIso,
    'entryTimeHour': entryTimeHour,
    'entryTimeMinute': entryTimeMinute,
    'queueArrivalTimeHour': queueArrivalTimeHour,
    'queueArrivalTimeMinute': queueArrivalTimeMinute,
    'happyEntryTimeHour': happyEntryTimeHour,
    'happyEntryTimeMinute': happyEntryTimeMinute,
    'exitTimeHour': exitTimeHour,
    'exitTimeMinute': exitTimeMinute,
    'numberOfPeople': numberOfPeople,
    'hasHappyEntry': hasHappyEntry,
    'canUseDpa': canUseDpa,
    'canUsePriorityPass': canUsePriorityPass,
    'canUseSingleRider': canUseSingleRider,
    'usesVacationPackage': usesVacationPackage,
    'usesFreeDrinkBenefit': usesFreeDrinkBenefit,
    'hasAttractionVoucher': hasAttractionVoucher,
    'hasShowVoucher': hasShowVoucher,
    'hasRestaurantReservation': hasRestaurantReservation,
    'wantsBreakfast': wantsBreakfast,
    'wantsLunch': wantsLunch,
    'wantsDinner': wantsDinner,
    'isRainy': isRainy,
    'hasChildren': hasChildren,
  };

  TripSettings copyWith({
    String? parkId,
    String? visitDateIso,
    int? entryTimeHour,
    int? entryTimeMinute,
    int? queueArrivalTimeHour,
    int? queueArrivalTimeMinute,
    int? happyEntryTimeHour,
    int? happyEntryTimeMinute,
    int? exitTimeHour,
    int? exitTimeMinute,
    int? numberOfPeople,
    bool? hasHappyEntry,
    bool? canUseDpa,
    bool? canUsePriorityPass,
    bool? canUseSingleRider,
    bool? usesVacationPackage,
    bool? usesFreeDrinkBenefit,
    bool? hasAttractionVoucher,
    bool? hasShowVoucher,
    bool? hasRestaurantReservation,
    bool? wantsBreakfast,
    bool? wantsLunch,
    bool? wantsDinner,
    bool? isRainy,
    bool? hasChildren,
  }) => TripSettings(
    parkId: parkId ?? this.parkId,
    visitDateIso: visitDateIso ?? this.visitDateIso,
    entryTimeHour: entryTimeHour ?? this.entryTimeHour,
    entryTimeMinute: entryTimeMinute ?? this.entryTimeMinute,
    queueArrivalTimeHour:
        queueArrivalTimeHour ?? this.queueArrivalTimeHour,
    queueArrivalTimeMinute:
        queueArrivalTimeMinute ?? this.queueArrivalTimeMinute,
    happyEntryTimeHour: happyEntryTimeHour ?? this.happyEntryTimeHour,
    happyEntryTimeMinute:
        happyEntryTimeMinute ?? this.happyEntryTimeMinute,
    exitTimeHour: exitTimeHour ?? this.exitTimeHour,
    exitTimeMinute: exitTimeMinute ?? this.exitTimeMinute,
    numberOfPeople: numberOfPeople ?? this.numberOfPeople,
    hasHappyEntry: hasHappyEntry ?? this.hasHappyEntry,
    canUseDpa: canUseDpa ?? this.canUseDpa,
    canUsePriorityPass: canUsePriorityPass ?? this.canUsePriorityPass,
    canUseSingleRider: canUseSingleRider ?? this.canUseSingleRider,
    usesVacationPackage: usesVacationPackage ?? this.usesVacationPackage,
    usesFreeDrinkBenefit: usesFreeDrinkBenefit ?? this.usesFreeDrinkBenefit,
    hasAttractionVoucher: hasAttractionVoucher ?? this.hasAttractionVoucher,
    hasShowVoucher: hasShowVoucher ?? this.hasShowVoucher,
    hasRestaurantReservation:
        hasRestaurantReservation ?? this.hasRestaurantReservation,
    wantsBreakfast: wantsBreakfast ?? this.wantsBreakfast,
    wantsLunch: wantsLunch ?? this.wantsLunch,
    wantsDinner: wantsDinner ?? this.wantsDinner,
    isRainy: isRainy ?? this.isRainy,
    hasChildren: hasChildren ?? this.hasChildren,
  );
}
