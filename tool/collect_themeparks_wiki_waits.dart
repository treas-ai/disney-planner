import 'dart:convert';
import 'dart:io';

import 'package:disney_planner/data/importers/historical_wait_data_importer.dart';
import 'package:disney_planner/data/providers/themeparks_wiki_live_parser.dart';
import 'package:disney_planner/domain/services/historical_wait_profile_generator.dart';
import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  final configFile = File('assets/master/live_mapping/themeparks_wiki_tokyo.json');
  if (!configFile.existsSync()) {
    stderr.writeln('Mapping not found: ${configFile.path}');
    exitCode = 66;
    return;
  }
  final config = jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
  final parks = options.parkId == 'all'
      ? const ['tokyo_disneyland', 'tokyo_disneysea']
      : [options.parkId];

  final client = http.Client();
  try {
    var iteration = 0;
    while (true) {
      iteration++;
      for (final parkId in parks) {
        await _collectPark(
          client: client,
          parkId: parkId,
          config: config,
          rebuild: options.rebuild,
        );
      }
      if (options.count > 0 && iteration >= options.count) break;
      if (options.count == 1) break;
      stdout.writeln('Next collection in ${options.intervalMinutes} minutes...');
      await Future<void>.delayed(Duration(minutes: options.intervalMinutes));
    }
  } finally {
    client.close();
  }
}

Future<void> _collectPark({
  required http.Client client,
  required String parkId,
  required Map<String, dynamic> config,
  required bool rebuild,
}) async {
  final park = config[parkId] as Map<String, dynamic>?;
  if (park == null) {
    stderr.writeln('Unknown park: $parkId');
    return;
  }
  final entityId = park['entityId']?.toString() ?? '';
  final rawAliases = park['aliases'] as Map<String, dynamic>? ?? const {};
  final aliases = <String, String>{
    for (final entry in rawAliases.entries)
      _normalize(entry.key): entry.value.toString(),
  };

  final uri = Uri.parse('https://api.themeparks.wiki/v1/entity/$entityId/live');
  http.Response response;
  try {
    response = await client.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'DisneyPlanner/1.0 wait-history collector',
      },
    );
  } catch (error) {
    stderr.writeln('$parkId: fetch failed: $error');
    return;
  }
  if (response.statusCode != 200) {
    stderr.writeln('$parkId: HTTP ${response.statusCode}');
    return;
  }

  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('$parkId: invalid JSON');
    return;
  }
  final entries = const ThemeParksWikiLiveParser().parse(decoded);
  final now = DateTime.now().toUtc();

  final rawDir = Directory('tool/wait_data/raw/$parkId');
  await rawDir.create(recursive: true);
  final stamp = now.toIso8601String().replaceAll(':', '-');
  await File('${rawDir.path}/$stamp.json').writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(decoded)}\n',
  );

  final csv = File('tool/wait_data/history/$parkId.csv');
  await csv.parent.create(recursive: true);
  if (!csv.existsSync()) {
    await csv.writeAsString(
      'parkId,facilityId,observedAt,waitMinutes,eventIds,isHoliday,isExcluded,exclusionReason\n',
    );
  }

  final existingKeys = <String>{};
  if (csv.existsSync()) {
    for (final line in await csv.readAsLines()) {
      if (line.startsWith('parkId,')) continue;
      final parts = line.split(',');
      if (parts.length >= 3) existingKeys.add('${parts[1]}|${parts[2]}');
    }
  }

  final unmatched = <String>[];
  final rows = <String>[];
  for (final entry in entries) {
    if (entry.entityType.toUpperCase() != 'ATTRACTION') continue;
    final wait = entry.standbyMinutes;
    if (wait == null || wait < 0) continue;
    final localId = aliases[_normalize(entry.name)];
    if (localId == null) {
      unmatched.add('${entry.name} (${entry.sourceEntityId})');
      continue;
    }
    final observedAt = entry.updatedAt.toUtc().toIso8601String();
    final key = '$localId|$observedAt';
    if (existingKeys.add(key)) {
      rows.add('$parkId,$localId,$observedAt,$wait,,,false,');
    }
  }
  if (rows.isNotEmpty) {
    await csv.writeAsString('${rows.join('\n')}\n', mode: FileMode.append);
  }

  final unmatchedFile = File('tool/wait_data/unmatched_$parkId.txt');
  if (unmatched.isNotEmpty) {
    await unmatchedFile.writeAsString('${unmatched.toSet().join('\n')}\n');
  } else if (unmatchedFile.existsSync()) {
    await unmatchedFile.delete();
  }

  stdout.writeln(
    '$parkId: ${rows.length} waits collected / ${unmatched.length} unmatched',
  );
  if (rebuild && rows.isNotEmpty) {
    await _rebuildProfiles(parkId, csv);
  }
}

Future<void> _rebuildProfiles(String parkId, File csv) async {
  final raw = await csv.readAsString();
  final imported = const HistoricalWaitDataImporter().importCsv(
    raw,
    source: 'ThemeParks.wiki live history',
  );
  if (!imported.isValid) {
    for (final error in imported.errors.take(10)) {
      stderr.writeln(error);
    }
    return;
  }
  final result = const HistoricalWaitProfileGenerator().generate(
    parkId: parkId,
    records: imported.records,
  );
  await _writeJson('assets/master/crowd_factors/$parkId.json', {
    'parkId': parkId,
    'status': result.factors.isEmpty ? 'not_calculated' : 'generated',
    'source': 'ThemeParks.wiki live history',
    'sampleCount': imported.records.length,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'items': result.factors.map((item) => item.toJson()).toList(),
  });
  await _writeJson('assets/master/wait_profiles/$parkId.json', {
    'parkId': parkId,
    'status': result.waitProfiles.isEmpty ? 'not_calculated' : 'generated',
    'source': 'ThemeParks.wiki live history',
    'sampleCount': imported.records.length,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'items': result.waitProfiles.map((item) => item.toJson()).toList(),
  });
  stdout.writeln(
    '$parkId: profiles rebuilt from ${imported.records.length} observations '
    '(${result.waitProfiles.length} facilities)',
  );
}

Future<void> _writeJson(String path, Map<String, dynamic> value) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(value)}\n',
  );
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll('&', 'and')
    .replaceAll(RegExp(r'[^a-z0-9]'), '');

class _Options {
  const _Options({
    required this.parkId,
    required this.intervalMinutes,
    required this.count,
    required this.rebuild,
  });

  final String parkId;
  final int intervalMinutes;
  final int count;
  final bool rebuild;

  static _Options parse(List<String> args) {
    var park = 'all';
    var interval = 5;
    var count = 1;
    var rebuild = true;
    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--park':
          if (i + 1 < args.length) park = args[++i];
          break;
        case '--interval-minutes':
          if (i + 1 < args.length) interval = int.tryParse(args[++i]) ?? 5;
          break;
        case '--count':
          if (i + 1 < args.length) count = int.tryParse(args[++i]) ?? 1;
          break;
        case '--continuous':
          count = 0;
          break;
        case '--no-rebuild':
          rebuild = false;
          break;
      }
    }
    return _Options(
      parkId: park,
      intervalMinutes: interval.clamp(5, 1440).toInt(),
      count: count,
      rebuild: rebuild,
    );
  }
}
