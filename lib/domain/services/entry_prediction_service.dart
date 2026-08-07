import '../entities/entry_prediction.dart';
import '../entities/trip_settings.dart';

class EntryPredictionService {
  const EntryPredictionService();

  static const int _gateToFirstFacilityMinutes = 5;
  static const int _happyEntryBookingMinutes = 5;

  EntryPrediction predict(TripSettings settings) {
    final queueArrival = _toMinutes(
      settings.queueArrivalTimeHour,
      settings.queueArrivalTimeMinute,
    );
    final officialOpening = _toMinutes(
      settings.entryTimeHour,
      settings.entryTimeMinute,
    );
    final admissionStart = settings.hasHappyEntry
        ? _toMinutes(
            settings.happyEntryTimeHour,
            settings.happyEntryTimeMinute,
          )
        : officialOpening;

    final queueLead = admissionStart - queueArrival;
    final gateDelay = settings.hasHappyEntry
        ? _estimateHappyEntryGateDelay(queueLead)
        : _estimateGeneralGateDelay(queueLead);
    final expectedEntry = queueArrival >= admissionStart
        ? queueArrival + gateDelay
        : admissionStart + gateDelay;

    final postEntryOperationMinutes = settings.hasHappyEntry &&
            (settings.canUseDpa || settings.canUsePriorityPass)
        ? _happyEntryBookingMinutes
        : 0;
    final firstFacilityArrival = expectedEntry +
        postEntryOperationMinutes + _gateToFirstFacilityMinutes;

    // ハッピーエントリー中は全施設が利用開始済みとは限らないため、
    // 汎用プランでは一般開園時刻を最初の施設利用可能時刻の下限とする。
    final firstFacilityAvailable = settings.hasHappyEntry
        ? _maximum(firstFacilityArrival, officialOpening)
        : firstFacilityArrival;

    return EntryPrediction(
      queueArrivalMinutes: queueArrival,
      officialOpeningMinutes: officialOpening,
      admissionStartMinutes: admissionStart,
      expectedEntryMinutes: expectedEntry,
      postEntryOperationMinutes: postEntryOperationMinutes,
      firstFacilityArrivalMinutes: firstFacilityArrival,
      firstFacilityAvailableMinutes: firstFacilityAvailable,
      queueLeadMinutes: queueLead,
      gateDelayMinutes: gateDelay,
      facilityOpeningWaitMinutes:
          firstFacilityAvailable - firstFacilityArrival,
      usesHappyEntryModel: settings.hasHappyEntry,
    );
  }

  int _estimateHappyEntryGateDelay(int queueLeadMinutes) {
    if (queueLeadMinutes >= 120) return 0;
    if (queueLeadMinutes >= 60) return 2;
    if (queueLeadMinutes >= 30) return 4;
    if (queueLeadMinutes >= 0) return 7;

    final minutesAfterAdmission = -queueLeadMinutes;
    if (minutesAfterAdmission >= 30) return 3;
    return 5;
  }

  int _estimateGeneralGateDelay(int queueLeadMinutes) {
    if (queueLeadMinutes >= 240) return 0;
    if (queueLeadMinutes >= 180) return 5;
    if (queueLeadMinutes >= 120) return 10;
    if (queueLeadMinutes >= 60) return 20;
    if (queueLeadMinutes >= 30) return 30;
    if (queueLeadMinutes >= 0) return 40;

    final minutesAfterOpening = -queueLeadMinutes;
    if (minutesAfterOpening >= 120) return 10;
    if (minutesAfterOpening >= 60) return 15;
    return 25;
  }

  int _maximum(int left, int right) => left > right ? left : right;
  int _toMinutes(int hour, int minute) => hour * 60 + minute;
}
