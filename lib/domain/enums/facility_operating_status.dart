enum FacilityOperatingStatus {
  operating(label: '営業中', closed: false),
  temporarilyClosed(label: '一時休止中', closed: true),
  scheduledClosure(label: '休止予定', closed: false),
  seasonalClosed(label: '季節休止中', closed: true),
  longTermClosed(label: '長期休止中', closed: true),
  permanentlyClosed(label: '運営終了', closed: true);

  const FacilityOperatingStatus({required this.label, required this.closed});

  final String label;
  final bool closed;
}
