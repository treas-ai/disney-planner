class ShareImportRecord {
  const ShareImportRecord({
    required this.importedAt,
    required this.sourceLabel,
    required this.kindLabel,
  });

  final DateTime importedAt;
  final String sourceLabel;
  final String kindLabel;

  Map<String, Object?> toJson() {
    return {
      'importedAt': importedAt.toIso8601String(),
      'sourceLabel': sourceLabel,
      'kindLabel': kindLabel,
    };
  }

  factory ShareImportRecord.fromJson(Map<String, Object?> json) {
    return ShareImportRecord(
      importedAt:
          DateTime.tryParse(json['importedAt']?.toString() ?? '') ??
          DateTime.now(),
      sourceLabel: json['sourceLabel']?.toString() ?? '不明',
      kindLabel: json['kindLabel']?.toString() ?? '共有データ',
    );
  }
}
