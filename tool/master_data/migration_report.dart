import 'dart:convert';
import 'dart:io';

import 'classifier_models.dart';

class MigrationReportWriter {
  const MigrationReportWriter({
    this.textReportFileName = 'migration_report.txt',
    this.jsonReportFileName = 'migration_report.json',
  });

  final String textReportFileName;
  final String jsonReportFileName;

  Future<MigrationReportOutput> write({
    required MigrationSummary summary,
    required Directory outputDirectory,
  }) async {
    if (!await outputDirectory.exists()) {
      await outputDirectory.create(recursive: true);
    }

    final textFile = File(
      '${outputDirectory.path}'
      '${Platform.pathSeparator}'
      '$textReportFileName',
    );

    final jsonFile = File(
      '${outputDirectory.path}'
      '${Platform.pathSeparator}'
      '$jsonReportFileName',
    );

    final textContent = buildTextReport(summary);

    final jsonContent = const JsonEncoder.withIndent(
      '  ',
    ).convert(summary.toJson());

    await textFile.writeAsString(textContent, flush: true);

    await jsonFile.writeAsString('$jsonContent\n', flush: true);

    return MigrationReportOutput(
      textReportPath: textFile.path,
      jsonReportPath: jsonFile.path,
    );
  }

  String buildTextReport(MigrationSummary summary) {
    final buffer = StringBuffer();

    _writeHeader(buffer: buffer, summary: summary);

    _writeOverallSummary(buffer: buffer, summary: summary);

    _writeClassificationSummary(buffer: buffer, summary: summary);

    _writeRestaurantTypeSummary(buffer: buffer, summary: summary);

    _writeShopTypeSummary(buffer: buffer, summary: summary);

    _writeChangedFileSummary(buffer: buffer, summary: summary);

    _writeChangedFacilityDetails(buffer: buffer, summary: summary);

    _writeManualReviewSection(buffer: buffer, summary: summary);

    _writeUnchangedFilesSection(buffer: buffer, summary: summary);

    _writeFooter(buffer: buffer, summary: summary);

    return buffer.toString();
  }

  void _writeHeader({
    required StringBuffer buffer,
    required MigrationSummary summary,
  }) {
    buffer.writeln(
      'Disney Planner '
      'マスターデータ移行レポート',
    );

    buffer.writeln('========================================');

    buffer.writeln();

    buffer.writeln(
      '実行モード：'
      '${summary.dryRun ? 'ドライラン' : '書き込み'}',
    );

    buffer.writeln(
      '開始時刻：'
      '${_formatDateTime(summary.startedAt)}',
    );

    buffer.writeln(
      '終了時刻：'
      '${_formatDateTime(summary.finishedAt)}',
    );

    buffer.writeln(
      '処理時間：'
      '${_formatDuration(summary.elapsed)}',
    );

    buffer.writeln();
  }

  void _writeOverallSummary({
    required StringBuffer buffer,
    required MigrationSummary summary,
  }) {
    buffer.writeln('【全体集計】');

    buffer.writeln(
      '対象ファイル数：'
      '${summary.fileCount}',
    );

    buffer.writeln(
      '書き込みファイル数：'
      '${summary.writtenFileCount}',
    );

    buffer.writeln(
      '対象施設数：'
      '${summary.facilityCount}',
    );

    buffer.writeln(
      '変更施設数：'
      '${summary.changedFacilityCount}',
    );

    buffer.writeln(
      '手動確認対象：'
      '${summary.manualReviewCount}',
    );

    buffer.writeln();
  }

  void _writeClassificationSummary({
    required StringBuffer buffer,
    required MigrationSummary summary,
  }) {
    buffer.writeln('【カテゴリ集計】');

    buffer.writeln(
      'レストラン：'
      '${summary.restaurantCount}',
    );

    buffer.writeln(
      'ショップ：'
      '${summary.shopCount}',
    );

    buffer.writeln(
      'カプセルトイ：'
      '${summary.capsuleToyCount}',
    );

    buffer.writeln(
      'モバイルオーダー対応：'
      '${summary.mobileOrderCount}',
    );

    buffer.writeln(
      'プライオリティ・'
      'シーティング対応：'
      '${summary.prioritySeatingCount}',
    );

    buffer.writeln(
      'スタンバイパス対応：'
      '${summary.standbyPassCount}',
    );

    buffer.writeln();
  }

  void _writeRestaurantTypeSummary({
    required StringBuffer buffer,
    required MigrationSummary summary,
  }) {
    final counts = _countByAfterValue(summary: summary, key: 'restaurantType');

    buffer.writeln('【レストラン種別】');

    _writeCountLine(
      buffer: buffer,
      label: 'テーブルサービス',
      value: counts['tableService'] ?? 0,
    );

    _writeCountLine(
      buffer: buffer,
      label: 'カウンターサービス',
      value: counts['counterService'] ?? 0,
    );

    _writeCountLine(
      buffer: buffer,
      label: 'ブッフェ',
      value: counts['buffet'] ?? 0,
    );

    _writeCountLine(
      buffer: buffer,
      label: 'ベーカリー・カフェ',
      value: counts['bakeryCafe'] ?? 0,
    );

    _writeCountLine(
      buffer: buffer,
      label: 'スナックスタンド',
      value: counts['snackStand'] ?? 0,
    );

    _writeCountLine(
      buffer: buffer,
      label: 'フードワゴン',
      value: counts['foodWagon'] ?? 0,
    );

    _writeCountLine(
      buffer: buffer,
      label: '対象外・未設定',
      value: counts['none'] ?? 0,
    );

    buffer.writeln();
  }

  void _writeShopTypeSummary({
    required StringBuffer buffer,
    required MigrationSummary summary,
  }) {
    final counts = _countByAfterValue(summary: summary, key: 'shopType');

    buffer.writeln('【ショップ種別】');

    _writeCountLine(
      buffer: buffer,
      label: 'グッズショップ',
      value: counts['general'] ?? 0,
    );

    _writeCountLine(
      buffer: buffer,
      label: 'カプセルトイ',
      value: counts['capsuleToy'] ?? 0,
    );

    _writeCountLine(
      buffer: buffer,
      label: 'アパレルショップ',
      value: counts['apparel'] ?? 0,
    );

    _writeCountLine(
      buffer: buffer,
      label: 'お菓子ショップ',
      value: counts['confectionery'] ?? 0,
    );

    _writeCountLine(
      buffer: buffer,
      label: 'お土産ショップ',
      value: counts['souvenir'] ?? 0,
    );

    _writeCountLine(
      buffer: buffer,
      label: '専門ショップ',
      value: counts['specialty'] ?? 0,
    );

    _writeCountLine(
      buffer: buffer,
      label: '期間限定ショップ',
      value: counts['limited'] ?? 0,
    );

    _writeCountLine(
      buffer: buffer,
      label: 'フォトサービス',
      value: counts['photoService'] ?? 0,
    );

    _writeCountLine(
      buffer: buffer,
      label: '対象外・未設定',
      value: counts['none'] ?? 0,
    );

    buffer.writeln();
  }

  void _writeChangedFileSummary({
    required StringBuffer buffer,
    required MigrationSummary summary,
  }) {
    buffer.writeln('【ファイル別集計】');

    if (summary.files.isEmpty) {
      buffer.writeln('対象ファイルはありません。');

      buffer.writeln();
      return;
    }

    for (final file in summary.files) {
      buffer.writeln('- ${file.assetPath}');

      buffer.writeln(
        '  施設数：'
        '${file.facilityCount}',
      );

      buffer.writeln(
        '  変更施設数：'
        '${file.changedFacilityCount}',
      );

      buffer.writeln(
        '  手動確認：'
        '${file.manualReviewCount}',
      );

      buffer.writeln(
        '  書き込み：'
        '${file.wasWritten ? 'あり' : 'なし'}',
      );
    }

    buffer.writeln();
  }

  void _writeChangedFacilityDetails({
    required StringBuffer buffer,
    required MigrationSummary summary,
  }) {
    final changedRecords = _allRecords(
      summary,
    ).where((record) => record.wasChanged);

    buffer.writeln('【変更施設一覧】');

    if (changedRecords.isEmpty) {
      buffer.writeln('変更された施設はありません。');

      buffer.writeln();
      return;
    }

    for (final record in changedRecords) {
      _writeFacilityRecord(
        buffer: buffer,
        record: record,
        includeBeforeAfter: true,
      );
    }

    buffer.writeln();
  }

  void _writeManualReviewSection({
    required StringBuffer buffer,
    required MigrationSummary summary,
  }) {
    final reviewRecords = _allRecords(
      summary,
    ).where((record) => record.requiresManualReview);

    buffer.writeln('【要手動確認】');

    if (reviewRecords.isEmpty) {
      buffer.writeln('手動確認が必要な施設はありません。');

      buffer.writeln();
      return;
    }

    for (final record in reviewRecords) {
      buffer.writeln('- ${record.source.name}');

      buffer.writeln(
        '  場所：'
        '${record.source.location}',
      );

      buffer.writeln(
        '  ID：'
        '${_fallbackText(record.source.id)}',
      );

      buffer.writeln(
        '  カテゴリ：'
        '${_fallbackText(record.source.category)}',
      );

      buffer.writeln(
        '  信頼度：'
        '${record.classification.confidence.label}',
      );

      buffer.writeln(
        '  理由：'
        '${record.classification.reason}',
      );

      buffer.writeln(
        '  適用ルール：'
        '${_fallbackText(record.classification.matchedRule)}',
      );

      buffer.writeln(
        '  shopType：'
        '${record.classification.shopType}',
      );

      buffer.writeln(
        '  restaurantType：'
        '${record.classification.restaurantType}',
      );

      buffer.writeln();
    }
  }

  void _writeUnchangedFilesSection({
    required StringBuffer buffer,
    required MigrationSummary summary,
  }) {
    final unchangedFiles = summary.files.where(
      (file) => file.changedFacilityCount == 0,
    );

    buffer.writeln('【変更なしファイル】');

    if (unchangedFiles.isEmpty) {
      buffer.writeln('すべての対象ファイルに変更があります。');

      buffer.writeln();
      return;
    }

    for (final file in unchangedFiles) {
      buffer.writeln('- ${file.assetPath}');
    }

    buffer.writeln();
  }

  void _writeFooter({
    required StringBuffer buffer,
    required MigrationSummary summary,
  }) {
    buffer.writeln('========================================');

    if (summary.dryRun) {
      buffer.writeln(
        'この実行はドライランです。'
        'JSONファイルは変更されていません。',
      );
    } else {
      buffer.writeln(
        'JSONファイルへの書き込み処理が'
        '完了しました。',
      );
    }

    if (summary.manualReviewCount > 0) {
      buffer.writeln(
        '要手動確認が'
        '${summary.manualReviewCount}件あります。',
      );

      buffer.writeln(
        '分類結果を確認してから'
        'MasterDataValidatorを実行してください。',
      );
    } else {
      buffer.writeln('要手動確認はありません。');

      buffer.writeln(
        'MasterDataValidatorによる検証へ'
        '進んでください。',
      );
    }
  }

  void _writeFacilityRecord({
    required StringBuffer buffer,
    required FacilityMigrationRecord record,
    required bool includeBeforeAfter,
  }) {
    buffer.writeln('- ${record.source.name}');

    buffer.writeln(
      '  場所：'
      '${record.source.location}',
    );

    buffer.writeln(
      '  ID：'
      '${_fallbackText(record.source.id)}',
    );

    buffer.writeln(
      '  カテゴリ：'
      '${_fallbackText(record.source.category)}',
    );

    buffer.writeln(
      '  変更項目：'
      '${record.changedKeys.join(', ')}',
    );

    buffer.writeln(
      '  信頼度：'
      '${record.classification.confidence.label}',
    );

    buffer.writeln(
      '  理由：'
      '${record.classification.reason}',
    );

    buffer.writeln(
      '  適用ルール：'
      '${_fallbackText(record.classification.matchedRule)}',
    );

    if (includeBeforeAfter) {
      for (final key in record.changedKeys) {
        buffer.writeln(
          '  $key：'
          '${_formatValue(record.before[key])}'
          ' → '
          '${_formatValue(record.after[key])}',
        );
      }
    }

    buffer.writeln();
  }

  Map<String, int> _countByAfterValue({
    required MigrationSummary summary,
    required String key,
  }) {
    final counts = <String, int>{};

    for (final record in _allRecords(summary)) {
      final value = record.after[key];

      if (value is! String) {
        continue;
      }

      counts.update(value, (count) => count + 1, ifAbsent: () => 1);
    }

    return counts;
  }

  Iterable<FacilityMigrationRecord> _allRecords(
    MigrationSummary summary,
  ) sync* {
    for (final file in summary.files) {
      yield* file.records;
    }
  }

  void _writeCountLine({
    required StringBuffer buffer,
    required String label,
    required int value,
  }) {
    buffer.writeln('$label：$value');
  }

  String _formatValue(dynamic value) {
    if (value == null) {
      return 'null';
    }

    if (value is String) {
      return value.isEmpty ? '空文字' : value;
    }

    if (value is bool || value is num) {
      return value.toString();
    }

    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }

  String _fallbackText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '未設定';
    }

    return value;
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();

    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 1) {
      return '${duration.inMilliseconds}ミリ秒';
    }

    if (duration.inMinutes < 1) {
      return '${duration.inSeconds}秒';
    }

    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);

    return '$minutes分$seconds秒';
  }
}

class MigrationReportOutput {
  const MigrationReportOutput({
    required this.textReportPath,
    required this.jsonReportPath,
  });

  final String textReportPath;
  final String jsonReportPath;

  Map<String, dynamic> toJson() {
    return {'textReportPath': textReportPath, 'jsonReportPath': jsonReportPath};
  }
}
