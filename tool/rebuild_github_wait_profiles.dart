import 'dart:convert';
import 'dart:io';

import 'package:disney_planner/data/importers/historical_wait_data_importer.dart';
import 'package:disney_planner/domain/entities/historical_wait_record.dart';
import 'package:disney_planner/domain/services/historical_wait_profile_generator.dart';

Future<void> main() async {
  for (final parkId in const ['tokyo_disneyland', 'tokyo_disneysea']) {
    await _rebuild(parkId);
  }
}

Future<void> _rebuild(String parkId) async {
  final records = <HistoricalWaitRecord>[];
  final importer = const HistoricalWaitDataImporter();

  // Keep compatibility with manually collected legacy history.
  final legacy = File('tool/wait_data/history/$parkId.csv');
  if (legacy.existsSync()) {
    final result = importer.importCsv(
      await legacy.readAsString(),
      source: 'ThemeParks.wiki legacy live history',
    );
    if (result.isValid) records.addAll(result.records);
  }

  final root = Directory('tool/wait_data/github_history');
  if (root.existsSync()) {
    final files = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('_$parkId.csv'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final converted = _convertGitHubCsv(await file.readAsLines());
      if (converted.isEmpty) continue;
      final result = importer.importCsv(
        converted,
        source: 'ThemeParks.wiki GitHub history',
      );
      if (!result.isValid) {
        stderr.writeln('${file.path}: ${result.errors.take(3).join('; ')}');
        continue;
      }
      records.addAll(result.records);
    }
  }

  final archiveRoot = Directory('tool/wait_data/archive/github_history');
  if (archiveRoot.existsSync()) {
    final files = archiveRoot
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('_${parkId}_waits.csv.gz'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final bytes = await file.readAsBytes();
      final decoded = utf8.decode(gzip.decode(bytes));
      final converted = _convertGitHubCsv(const LineSplitter().convert(decoded));
      if (converted.isEmpty) continue;
      final archiveResult = importer.importCsv(
        converted,
        source: 'ThemeParks.wiki GitHub monthly archive',
      );
      if (!archiveResult.isValid) {
        stderr.writeln('${file.path}: ${archiveResult.errors.take(3).join('; ')}');
        continue;
      }
      records.addAll(archiveResult.records);
    }
  }

  final result = const HistoricalWaitProfileGenerator().generate(
    parkId: parkId,
    records: records,
  );
  final generatedAt = DateTime.now().toUtc().toIso8601String();
  await _writeJson('assets/master/crowd_factors/$parkId.json', {
    'parkId': parkId,
    'status': result.factors.isEmpty ? 'not_calculated' : 'generated',
    'source': 'ThemeParks.wiki accumulated history',
    'sampleCount': records.length,
    'generatedAt': generatedAt,
    'items': result.factors.map((item) => item.toJson()).toList(),
  });
  await _writeJson('assets/master/wait_profiles/$parkId.json', {
    'parkId': parkId,
    'status': result.waitProfiles.isEmpty ? 'not_calculated' : 'generated',
    'source': 'ThemeParks.wiki accumulated history',
    'sampleCount': records.length,
    'generatedAt': generatedAt,
    'items': result.waitProfiles.map((item) => item.toJson()).toList(),
  });
  stdout.writeln('$parkId: rebuilt from ${records.length} observations');
}

String _convertGitHubCsv(List<String> lines) {
  if (lines.length <= 1) return '';
  final output = <String>[
    'parkId,facilityId,observedAt,waitMinutes,eventIds,isHoliday,isExcluded,exclusionReason',
  ];
  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) continue;
    // Collector fields before status/sourceEntityId contain no commas.
    final parts = line.split(',');
    if (parts.length < 4) continue;
    output.add('${parts[0]},${parts[1]},${parts[2]},${parts[3]},,,false,');
  }
  return '${output.join('\n')}\n';
}

Future<void> _writeJson(String path, Map<String, dynamic> value) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(value)}\n',
  );
}
