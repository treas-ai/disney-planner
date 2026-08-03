enum LivePassType {
  dpa,
  priorityPass,
  standbyPass,
  entryRequest;

  String get label {
    return switch (this) {
      LivePassType.dpa => 'DPA',
      LivePassType.priorityPass => 'Priority Pass',
      LivePassType.standbyPass => 'Standby Pass',
      LivePassType.entryRequest => 'Entry Request',
    };
  }
}

enum LivePassAvailability {
  available,
  unavailable,
  suspended,
  unknown;

  String get label {
    return switch (this) {
      LivePassAvailability.available => '利用可能',
      LivePassAvailability.unavailable => '終了',
      LivePassAvailability.suspended => '一時停止',
      LivePassAvailability.unknown => '情報なし',
    };
  }
}

class LivePassStatus {
  const LivePassStatus({
    required this.parkId,
    required this.facilityId,
    required this.type,
    required this.availability,
    required this.updatedAt,
    this.message,
  });

  factory LivePassStatus.fromJson(Map<String, dynamic> json) {
    return LivePassStatus(
      parkId: json['parkId'] as String? ?? '',
      facilityId: json['facilityId'] as String? ?? '',
      type: LivePassType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => LivePassType.dpa,
      ),
      availability: LivePassAvailability.values.firstWhere(
        (value) => value.name == json['availability'],
        orElse: () => LivePassAvailability.unknown,
      ),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      message: json['message'] as String?,
    );
  }

  final String parkId;
  final String facilityId;
  final LivePassType type;
  final LivePassAvailability availability;
  final DateTime updatedAt;
  final String? message;

  bool get isValid {
    return parkId.trim().isNotEmpty && facilityId.trim().isNotEmpty;
  }

  Map<String, dynamic> toJson() {
    return {
      'parkId': parkId,
      'facilityId': facilityId,
      'type': type.name,
      'availability': availability.name,
      'updatedAt': updatedAt.toIso8601String(),
      'message': message,
    };
  }
}
