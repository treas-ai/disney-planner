import 'dart:convert';
import 'dart:io';

import 'package:disney_planner/data/importers/historical_wait_data_importer.dart';
import 'package:disney_planner/domain/services/historical_wait_profile_generator.dart';

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    stderr.writeln('Usage: dart run tool/generate_historical_wait_profiles.dart <parkId> <input.csv|json> <source>');
    exitCode = 64;
    return;
  }
  final parkId = args[0];
  final input = File(args[1]);
  final source = args[2];
  if (!await input.exists()) {
    stderr.writeln('Input file not found: ${input.path}');
    exitCode = 66;
    return;
  }
  final raw = await input.readAsString();
  const importer = HistoricalWaitDataImporter();
  final imported = input.path.toLowerCase().endsWith('.csv')
      ? importer.importCsv(raw, source: source)
      : importer.importJson(raw, source: source);
  if (!imported.isValid) {
    for (final error in imported.errors) {
      stderr.writeln(error);
    }
    exitCode = 65;
    return;
  }
  const generator = HistoricalWaitProfileGenerator();
  final result = generator.generate(parkId: parkId, records: imported.records);
  await _write('assets/master/crowd_factors/$parkId.json', {
    'parkId': parkId,
    'status': result.factors.isEmpty ? 'not_calculated' : 'generated',
    'items': result.factors.map((item) => item.toJson()).toList(),
  });
  await _write('assets/master/wait_profiles/$parkId.json', {
    'parkId': parkId,
    'status': result.waitProfiles.isEmpty ? 'not_calculated' : 'generated',
    'items': result.waitProfiles.map((item) => item.toJson()).toList(),
  });
  stdout.writeln('Imported: ${imported.records.length}');
  stdout.writeln('Crowd factors: ${result.factors.length}');
  stdout.writeln('Wait profiles: ${result.waitProfiles.length}');
}

Future<void> _write(String path, Map<String, dynamic> json) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString('${const JsonEncoder.withIndent('  ').convert(json)}\n');
}
