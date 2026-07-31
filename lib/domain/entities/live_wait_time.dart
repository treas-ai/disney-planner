class LiveWaitTime {
  const LiveWaitTime({
    required this.facilityId,
    required this.parkId,
    required this.waitMinutes,
    required this.updatedAt,
    this.source = LiveWaitTimeSource.manual,
  });

  factory LiveWaitTime.fromJson(Map<String, dynamic> json) {
    return LiveWaitTime(
      facilityId: json['facilityId'] as String? ?? '',
      parkId: json['parkId'] as String? ?? '',
      waitMinutes: json['waitMinutes'] as int? ?? 0,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      source: LiveWaitTimeSource.values.firstWhere(
        (source) => source.name == json['source'],
        orElse: () => LiveWaitTimeSource.manual,
      ),
    );
  }

  final String facilityId;
  final String parkId;
  final int waitMinutes;
  final DateTime updatedAt;
  final LiveWaitTimeSource source;

  bool get isValid {
    return facilityId.trim().isNotEmpty &&
        parkId.trim().isNotEmpty &&
        waitMinutes >= 0;
  }

  bool isStaleAt(
    DateTime now, {
    Duration staleAfter = const Duration(minutes: 30),
  }) {
    return now.difference(updatedAt) >= staleAfter;
  }

  Duration ageAt(DateTime now) {
    final difference = now.difference(updatedAt);

    if (difference.isNegative) {
      return Duration.zero;
    }

    return difference;
  }

  String updatedAtLabel({DateTime? now}) {
    final localUpdatedAt = updatedAt.toLocal();
    final referenceNow = (now ?? DateTime.now()).toLocal();

    final isSameDate =
        localUpdatedAt.year == referenceNow.year &&
        localUpdatedAt.month == referenceNow.month &&
        localUpdatedAt.day == referenceNow.day;

    final hour = localUpdatedAt.hour.toString().padLeft(2, '0');
    final minute = localUpdatedAt.minute.toString().padLeft(2, '0');

    if (isSameDate) {
      return '$hour:$minute';
    }

    final month = localUpdatedAt.month.toString().padLeft(2, '0');
    final day = localUpdatedAt.day.toString().padLeft(2, '0');

    return '$month/$day $hour:$minute';
  }

  String ageLabel({DateTime? now}) {
    final age = ageAt(now ?? DateTime.now());

    if (age.inMinutes < 1) {
      return 'たった今';
    }

    if (age.inMinutes < 60) {
      return '${age.inMinutes}分前';
    }

    if (age.inHours < 24) {
      return '${age.inHours}時間前';
    }

    return '${age.inDays}日前';
  }

  LiveWaitTime copyWith({
    String? facilityId,
    String? parkId,
    int? waitMinutes,
    DateTime? updatedAt,
    LiveWaitTimeSource? source,
  }) {
    return LiveWaitTime(
      facilityId: facilityId ?? this.facilityId,
      parkId: parkId ?? this.parkId,
      waitMinutes: waitMinutes ?? this.waitMinutes,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'facilityId': facilityId,
      'parkId': parkId,
      'waitMinutes': waitMinutes,
      'updatedAt': updatedAt.toIso8601String(),
      'source': source.name,
    };
  }
}

enum LiveWaitTimeSource {
  manual(label: '手動入力'),
  realtime(label: 'リアルタイム取得'),
  estimated(label: '推定値');

  const LiveWaitTimeSource({required this.label});

  final String label;
}
