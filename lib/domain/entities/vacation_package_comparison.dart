enum VacationPackageAttractionTicketType {
  facilityAndTimeSpecified,
  facilitySpecifiedTimeFlexible,
  facilityAndTimeFlexible,
  unlimitedRides,
}

class VacationPackageAttractionOption {
  const VacationPackageAttractionOption({
    required this.type,
    required this.label,
    required this.usageSummary,
    required this.canSimulateFromCurrentSettings,
  });

  final VacationPackageAttractionTicketType type;
  final String label;
  final String usageSummary;
  final bool canSimulateFromCurrentSettings;
}

abstract final class VacationPackageComparisonCatalog {
  static const String officialSnapshotDate = '2026-09-23';

  static const List<VacationPackageAttractionOption> attractionOptions = [
    VacationPackageAttractionOption(
      type: VacationPackageAttractionTicketType.facilityAndTimeSpecified,
      label: '施設・時間指定あり',
      usageSummary: '予約時に選択した施設を指定日時に利用するタイプ',
      canSimulateFromCurrentSettings: false,
    ),
    VacationPackageAttractionOption(
      type: VacationPackageAttractionTicketType.facilitySpecifiedTimeFlexible,
      label: '施設指定あり・時間指定なし',
      usageSummary: '指定施設を運営時間内の好きな時間に1回利用するタイプ',
      canSimulateFromCurrentSettings: false,
    ),
    VacationPackageAttractionOption(
      type: VacationPackageAttractionTicketType.facilityAndTimeFlexible,
      label: '施設・時間指定なし',
      usageSummary: '対象施設から選び、運営時間内の好きな時間に1回利用するタイプ',
      canSimulateFromCurrentSettings: false,
    ),
    VacationPackageAttractionOption(
      type: VacationPackageAttractionTicketType.unlimitedRides,
      label: '乗り放題',
      usageSummary: '対象施設を時間指定なしで少ない待ち時間で何度でも利用するタイプ',
      canSimulateFromCurrentSettings: true,
    ),
  ];
}
