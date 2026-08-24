class OfficialPerformanceOpportunity {
  const OfficialPerformanceOpportunity({
    required this.facilityId,
    required this.name,
    required this.startMinutes,
    required this.endMinutes,
    this.requiresEntryRequest = false,
    this.supportsDpa = false,
    this.isSelected = false,
  });

  final String facilityId;
  final String name;
  final int startMinutes;
  final int endMinutes;
  final bool requiresEntryRequest;
  final bool supportsDpa;
  final bool isSelected;

  String get startLabel {
    final hour = (startMinutes ~/ 60).toString().padLeft(2, '0');
    final minute = (startMinutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get accessLabel {
    final parts = <String>[];
    if (requiresEntryRequest) {
      parts.add('エントリー受付対象');
    }
    if (supportsDpa) {
      parts.add('DPA対象');
    }
    return parts.isEmpty ? '' : '（${parts.join('・')}）';
  }

  String get displayLabel => '$startLabel $name$accessLabel';
}
