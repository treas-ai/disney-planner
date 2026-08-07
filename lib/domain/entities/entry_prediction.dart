class EntryPrediction {
  const EntryPrediction({
    required this.queueArrivalMinutes,
    required this.officialOpeningMinutes,
    required this.admissionStartMinutes,
    required this.expectedEntryMinutes,
    required this.postEntryOperationMinutes,
    required this.firstFacilityArrivalMinutes,
    required this.firstFacilityAvailableMinutes,
    required this.queueLeadMinutes,
    required this.gateDelayMinutes,
    required this.facilityOpeningWaitMinutes,
    required this.usesHappyEntryModel,
  });

  final int queueArrivalMinutes;
  final int officialOpeningMinutes;
  final int admissionStartMinutes;
  final int expectedEntryMinutes;
  final int postEntryOperationMinutes;
  final int firstFacilityArrivalMinutes;
  final int firstFacilityAvailableMinutes;
  final int queueLeadMinutes;
  final int gateDelayMinutes;
  final int facilityOpeningWaitMinutes;
  final bool usesHappyEntryModel;

  int get firstActivityReadyMinutes => firstFacilityAvailableMinutes;

  String get queueArrivalLabel => _format(queueArrivalMinutes);
  String get officialOpeningLabel => _format(officialOpeningMinutes);
  String get admissionStartLabel => _format(admissionStartMinutes);
  String get effectiveOpeningLabel => admissionStartLabel;
  String get expectedEntryLabel => _format(expectedEntryMinutes);
  String get firstFacilityArrivalLabel => _format(firstFacilityArrivalMinutes);
  String get firstFacilityAvailableLabel =>
      _format(firstFacilityAvailableMinutes);
  String get firstActivityReadyLabel => firstFacilityAvailableLabel;

  static String _format(int minutes) {
    final normalized = minutes.clamp(0, 24 * 60 - 1);
    final hour = normalized ~/ 60;
    final minute = normalized % 60;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }
}
