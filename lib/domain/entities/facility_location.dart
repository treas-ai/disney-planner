class FacilityLocation {
  const FacilityLocation({
    required this.parkId,
    required this.facilityId,
    required this.areaId,
    required this.x,
    required this.y,
    this.exitAreaId,
    this.possibleExitAreaIds = const [],
  });

  factory FacilityLocation.fromJson(Map<String, dynamic> json) {
    final rawExitAreaId = json['exitAreaId'] as String?;
    final rawPossibleExitAreaIds = json['possibleExitAreaIds'];
    final possibleExitAreaIds = rawPossibleExitAreaIds is List
        ? rawPossibleExitAreaIds
              .whereType<String>()
              .where((value) => value.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    return FacilityLocation(
      parkId: json['parkId'] as String? ?? '',
      facilityId: json['facilityId'] as String? ?? '',
      areaId: json['areaId'] as String? ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      exitAreaId: rawExitAreaId == null || rawExitAreaId.isEmpty
          ? null
          : rawExitAreaId,
      possibleExitAreaIds: possibleExitAreaIds,
    );
  }

  final String parkId;
  final String facilityId;

  /// Area where the guest enters/boards the facility.
  final String areaId;
  final double x;
  final double y;

  /// Deterministic area where the guest is physically located after use.
  ///
  /// Ordinary facilities omit this and remain in [areaId].
  /// A fixed-route transport attraction can set a different area.
  final String? exitAreaId;

  /// Candidate exit areas when the actual route/destination changes by time.
  ///
  /// When this contains multiple values and [exitAreaId] is null, the
  /// scheduler must not guess a destination.
  final List<String> possibleExitAreaIds;

  bool get hasAmbiguousExit =>
      exitAreaId == null && possibleExitAreaIds.length > 1;

  String get effectiveExitAreaId =>
      hasAmbiguousExit ? areaId : (exitAreaId ?? areaId);

  bool get changesGuestArea =>
      !hasAmbiguousExit && effectiveExitAreaId != areaId;

  Map<String, dynamic> toJson() {
    return {
      'parkId': parkId,
      'facilityId': facilityId,
      'areaId': areaId,
      'x': x,
      'y': y,
      if (exitAreaId != null) 'exitAreaId': exitAreaId,
      if (possibleExitAreaIds.isNotEmpty)
        'possibleExitAreaIds': possibleExitAreaIds,
    };
  }
}
