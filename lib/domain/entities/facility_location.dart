class FacilityLocation {
  const FacilityLocation({
    required this.parkId,
    required this.facilityId,
    required this.areaId,
    required this.x,
    required this.y,
  });

  factory FacilityLocation.fromJson(Map<String, dynamic> json) {
    return FacilityLocation(
      parkId: json['parkId'] as String? ?? '',
      facilityId: json['facilityId'] as String? ?? '',
      areaId: json['areaId'] as String? ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
    );
  }

  final String parkId;
  final String facilityId;
  final String areaId;
  final double x;
  final double y;

  Map<String, dynamic> toJson() {
    return {
      'parkId': parkId,
      'facilityId': facilityId,
      'areaId': areaId,
      'x': x,
      'y': y,
    };
  }
}
