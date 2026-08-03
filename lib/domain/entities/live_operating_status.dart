enum LiveOperatingState {
  operating,
  temporarilyClosed,
  closed,
  unknown;

  String get label {
    return switch (this) {
      LiveOperatingState.operating => '営業中',
      LiveOperatingState.temporarilyClosed => '一時休止',
      LiveOperatingState.closed => '休止中',
      LiveOperatingState.unknown => '情報なし',
    };
  }
}

class LiveOperatingStatus {
  const LiveOperatingStatus({
    required this.parkId,
    required this.facilityId,
    required this.state,
    required this.updatedAt,
    this.message,
  });

  factory LiveOperatingStatus.fromJson(Map<String, dynamic> json) {
    return LiveOperatingStatus(
      parkId: json['parkId'] as String? ?? '',
      facilityId: json['facilityId'] as String? ?? '',
      state: LiveOperatingState.values.firstWhere(
        (value) => value.name == json['state'],
        orElse: () => LiveOperatingState.unknown,
      ),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      message: json['message'] as String?,
    );
  }

  final String parkId;
  final String facilityId;
  final LiveOperatingState state;
  final DateTime updatedAt;
  final String? message;

  bool get isValid {
    return parkId.trim().isNotEmpty && facilityId.trim().isNotEmpty;
  }

  Map<String, dynamic> toJson() {
    return {
      'parkId': parkId,
      'facilityId': facilityId,
      'state': state.name,
      'updatedAt': updatedAt.toIso8601String(),
      'message': message,
    };
  }
}
