class AreaConnection {
  const AreaConnection({
    required this.parkId,
    required this.fromAreaId,
    required this.toAreaId,
    required this.minutes,
    this.bidirectional = true,
    this.note,
  });

  factory AreaConnection.fromJson(Map<String, dynamic> json) {
    return AreaConnection(
      parkId: json['parkId'] as String? ?? '',
      fromAreaId: json['fromAreaId'] as String? ?? '',
      toAreaId: json['toAreaId'] as String? ?? '',
      minutes: json['minutes'] as int? ?? 0,
      bidirectional: json['bidirectional'] as bool? ?? true,
      note: json['note'] as String?,
    );
  }

  final String parkId;
  final String fromAreaId;
  final String toAreaId;
  final int minutes;
  final bool bidirectional;
  final String? note;

  bool connects(String from, String to) {
    if (fromAreaId == from && toAreaId == to) {
      return true;
    }

    return bidirectional && fromAreaId == to && toAreaId == from;
  }

  Map<String, dynamic> toJson() {
    return {
      'parkId': parkId,
      'fromAreaId': fromAreaId,
      'toAreaId': toAreaId,
      'minutes': minutes,
      'bidirectional': bidirectional,
      'note': note,
    };
  }
}
