enum PlanExplanationReasonCategory {
  fixedTime('固定時刻'),
  preferredTime('時間条件'),
  waitTime('待ち時間'),
  movement('移動'),
  freeTime('自由時間'),
  priority('希望優先'),
  access('利用方法'),
  scheduledWish('希望採用');

  const PlanExplanationReasonCategory(this.label);
  final String label;
}

class PlanExplanationItem {
  const PlanExplanationItem({
    required this.scheduleItemId,
    required this.title,
    required this.timeRange,
    required this.reason,
    required this.detailReason,
    required this.category,
    required this.evidence,
  });

  final String scheduleItemId;
  final String title;
  final String timeRange;
  final String reason;
  final String detailReason;
  final PlanExplanationReasonCategory category;
  final String evidence;
}

class UnmetWishExplanation {
  const UnmetWishExplanation({
    required this.facilityId,
    required this.title,
    required this.requestedCount,
    required this.scheduledCount,
    required this.reason,
    required this.detailReason,
  });

  final String facilityId;
  final String title;
  final int requestedCount;
  final int scheduledCount;
  final String reason;
  final String detailReason;
}

class PlanExplanation {
  const PlanExplanation({
    required this.modeSummary,
    required this.featureSummary,
    required this.items,
    required this.unmetWishes,
  });

  final String modeSummary;
  final String featureSummary;
  final List<PlanExplanationItem> items;
  final List<UnmetWishExplanation> unmetWishes;
}
