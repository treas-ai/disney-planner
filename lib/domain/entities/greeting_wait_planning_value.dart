class GreetingWaitPlanningValue {
  const GreetingWaitPlanningValue({
    required this.facilityId,
    required this.waitMinutes,
    required this.baseWaitMinutes,
    required this.parkCrowdMultiplier,
    required this.isCharacterBirthday,
    required this.birthdayCharacterNames,
    required this.birthdayPlanningWaitMinutes,
    required this.birthdayExtremeRiskMinutes,
    required this.birthdayOpeningUrgencyBonus,
    required this.source,
  });

  final String facilityId;
  final int waitMinutes;
  final int baseWaitMinutes;
  final double parkCrowdMultiplier;
  final bool isCharacterBirthday;
  final List<String> birthdayCharacterNames;
  final int birthdayPlanningWaitMinutes;
  final int birthdayExtremeRiskMinutes;
  final double birthdayOpeningUrgencyBonus;
  final String source;
}
