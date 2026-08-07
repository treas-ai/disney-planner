import 'dart:convert';
import 'dart:io';

import 'package:disney_planner/data/local/master_data/data_quality/master_data_audit_issue.dart';
import 'package:disney_planner/data/local/master_data/data_quality/master_data_audit_report.dart';
import 'package:disney_planner/data/local/master_data/data_quality/master_data_auditor.dart';

Future<void> main(List<String> arguments) async {
  const manifestPath = 'assets/master/master_manifest.json';
  final manifestFile = File(manifestPath);

  if (!manifestFile.existsSync()) {
    stderr.writeln('Manifest not found: $manifestPath');
    exitCode = 2;
    return;
  }

  final manifest = jsonDecode(await manifestFile.readAsString());
  if (manifest is! Map<String, dynamic>) {
    stderr.writeln('Manifest root must be an object.');
    exitCode = 2;
    return;
  }

  final facilityFiles =
      (manifest['facilityFiles'] as List?)?.whereType<String>().toList(
        growable: false,
      ) ??
      const <String>[];
  final rowsByFile = <String, List<Map<String, dynamic>>>{};

  for (final path in facilityFiles) {
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('Facility file not found: $path');
      exitCode = 2;
      return;
    }

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) {
      stderr.writeln('Facility file root must be an array: $path');
      exitCode = 2;
      return;
    }

    rowsByFile[path] = decoded
        .whereType<Map>()
        .map((row) {
          return Map<String, dynamic>.from(row);
        })
        .toList(growable: false);
  }

  final report = const MasterDataAuditor().audit(
    facilityRowsByFile: rowsByFile,
  );
  final output = File('docs/audits/MASTER_DATA_AUDIT_REPORT.md');
  await output.writeAsString(_toMarkdown(report));

  stdout.writeln('Facilities: ${report.facilityCount}');
  stdout.writeln('Errors: ${report.errorCount}');
  stdout.writeln('Warnings: ${report.warningCount}');
  stdout.writeln('Information: ${report.informationCount}');
  stdout.writeln('Report: ${output.path}');

  if (report.hasErrors) {
    exitCode = 1;
  }
}

String _toMarkdown(MasterDataAuditReport report) {
  final buffer = StringBuffer()
    ..writeln('# Master Data Audit Report')
    ..writeln()
    ..writeln('- Generated: ${report.generatedAt.toIso8601String()}')
    ..writeln('- Facilities: ${report.facilityCount}')
    ..writeln('- Errors: ${report.errorCount}')
    ..writeln('- Warnings: ${report.warningCount}')
    ..writeln('- Information: ${report.informationCount}')
    ..writeln()
    ..writeln('## Counts by park');

  for (final entry in report.countByPark.entries) {
    buffer.writeln('- `${entry.key}`: ${entry.value}');
  }

  buffer
    ..writeln()
    ..writeln('## Counts by category');

  for (final entry in report.countByCategory.entries) {
    buffer.writeln('- `${entry.key}`: ${entry.value}');
  }

  buffer
    ..writeln()
    ..writeln('## Issues');

  if (report.issues.isEmpty) {
    buffer.writeln('No issues found.');
  } else {
    for (final issue in report.issues) {
      buffer.writeln(
        '- **${_severityLabel(issue.severity)}** '
        '`${issue.code}` `${issue.location}`: ${issue.message}',
      );
    }
  }

  return buffer.toString();
}

String _severityLabel(MasterDataAuditSeverity severity) {
  return switch (severity) {
    MasterDataAuditSeverity.error => 'ERROR',
    MasterDataAuditSeverity.warning => 'WARNING',
    MasterDataAuditSeverity.information => 'INFO',
  };
}

