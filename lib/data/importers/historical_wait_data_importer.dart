import 'dart:convert';

import '../../domain/entities/historical_wait_record.dart';

class HistoricalWaitImportResult {
  const HistoricalWaitImportResult({
    required this.records,
    required this.errors,
    required this.sourceRows,
  });

  final List<HistoricalWaitRecord> records;
  final List<String> errors;
  final int sourceRows;

  bool get isValid => errors.isEmpty;
}

class HistoricalWaitDataImporter {
  const HistoricalWaitDataImporter();

  HistoricalWaitImportResult importJson(String raw, {required String source}) {
    final errors = <String>[];
    final records = <HistoricalWaitRecord>[];
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (error) {
      return HistoricalWaitImportResult(
        records: const [],
        errors: ['JSONを解析できません: $error'],
        sourceRows: 0,
      );
    }
    final rows = decoded is List<dynamic>
        ? decoded
        : decoded is Map<String, dynamic>
        ? decoded['items'] as List<dynamic>? ?? const []
        : const <dynamic>[];
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      if (row is! Map<String, dynamic>) {
        errors.add('${index + 1}行目: オブジェクトではありません。');
        continue;
      }
      _append(row, source: source, rowNumber: index + 1, records: records, errors: errors);
    }
    return HistoricalWaitImportResult(
      records: List.unmodifiable(records),
      errors: List.unmodifiable(errors),
      sourceRows: rows.length,
    );
  }

  HistoricalWaitImportResult importCsv(String raw, {required String source}) {
    final lines = const LineSplitter().convert(raw).where((line) => line.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      return const HistoricalWaitImportResult(records: [], errors: ['CSVが空です。'], sourceRows: 0);
    }
    final headers = _parseCsvLine(lines.first);
    final records = <HistoricalWaitRecord>[];
    final errors = <String>[];
    for (var index = 1; index < lines.length; index++) {
      final values = _parseCsvLine(lines[index]);
      final row = <String, dynamic>{};
      for (var column = 0; column < headers.length; column++) {
        row[headers[column]] = column < values.length ? values[column] : '';
      }
      _append(row, source: source, rowNumber: index + 1, records: records, errors: errors);
    }
    return HistoricalWaitImportResult(
      records: List.unmodifiable(records),
      errors: List.unmodifiable(errors),
      sourceRows: lines.length - 1,
    );
  }

  void _append(
    Map<String, dynamic> row, {
    required String source,
    required int rowNumber,
    required List<HistoricalWaitRecord> records,
    required List<String> errors,
  }) {
    final parkId = row['parkId']?.toString().trim() ?? '';
    final facilityId = row['facilityId']?.toString().trim() ?? '';
    final observedAt = DateTime.tryParse(row['observedAt']?.toString() ?? '');
    final waitMinutes = int.tryParse(row['waitMinutes']?.toString() ?? '');
    if (parkId.isEmpty || facilityId.isEmpty || observedAt == null || waitMinutes == null || waitMinutes < 0) {
      errors.add('$rowNumber行目: parkId/facilityId/observedAt/waitMinutesが不正です。');
      return;
    }
    final eventIds = row['eventIds'] is List<dynamic>
        ? (row['eventIds'] as List<dynamic>).map((value) => value.toString()).toList(growable: false)
        : (row['eventIds']?.toString() ?? '').split('|').map((value) => value.trim()).where((value) => value.isNotEmpty).toList(growable: false);
    records.add(HistoricalWaitRecord(
      parkId: parkId,
      facilityId: facilityId,
      observedAt: observedAt,
      waitMinutes: waitMinutes,
      source: source,
      eventIds: eventIds,
      isHoliday: _readBool(row['isHoliday']),
      isExcluded: _readBool(row['isExcluded']),
      exclusionReason: row['exclusionReason']?.toString(),
    ));
  }

  bool _readBool(Object? value) => value == true || value?.toString().toLowerCase() == 'true' || value?.toString() == '1';

  List<String> _parseCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (var index = 0; index < line.length; index++) {
      final char = line[index];
      if (char == '"') {
        if (quoted && index + 1 < line.length && line[index + 1] == '"') {
          buffer.write('"');
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        values.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    values.add(buffer.toString().trim());
    return values;
  }
}
