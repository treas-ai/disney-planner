import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final root = Directory.current;
  final packFile = File(
    '${root.path}/assets/master/events/wish_packs/summer_2026.json',
  );

  if (!await packFile.exists()) {
    stderr.writeln('Wish data pack not found.');
    exitCode = 1;
    return;
  }

  final json = jsonDecode(await packFile.readAsString());
  final items = (json['items'] as List? ?? const [])
      .whereType<Map>()
      .map(
        (item) => {
          for (final entry in item.entries) entry.key.toString(): entry.value,
        },
      )
      .toList(growable: false);

  final errors = <String>[];
  final warnings = <String>[];
  final ids = <String>{};
  final counts = <String, int>{};

  for (final item in items) {
    final id = item['id']?.toString() ?? '';
    final name = item['name']?.toString() ?? '';
    final category = item['category']?.toString() ?? '';
    final start = DateTime.tryParse(item['startDate']?.toString() ?? '');
    final end = DateTime.tryParse(item['endDate']?.toString() ?? '');

    if (id.isEmpty || name.isEmpty || category.isEmpty) {
      errors.add('Required field missing: $item');
      continue;
    }
    if (!ids.add(id)) {
      errors.add('Duplicate id: $id');
    }
    if (start == null || end == null || end.isBefore(start)) {
      errors.add('Invalid sales period: $id');
    }
    final venues = item['venueNames'] as List? ?? const [];
    if (venues.isEmpty) {
      warnings.add('No venue name: $id');
    }
    counts[category] = (counts[category] ?? 0) + 1;
  }

  final buffer = StringBuffer()
    ..writeln('# WISH_DATA_AUDIT_REPORT')
    ..writeln()
    ..writeln('- Items: ${items.length}')
    ..writeln('- Errors: ${errors.length}')
    ..writeln('- Warnings: ${warnings.length}')
    ..writeln()
    ..writeln('## Category counts');
  for (final entry
      in counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
    buffer.writeln('- ${entry.key}: ${entry.value}');
  }
  buffer
    ..writeln()
    ..writeln('## Errors');
  if (errors.isEmpty) {
    buffer.writeln('- None');
  } else {
    for (final error in errors) {
      buffer.writeln('- $error');
    }
  }
  buffer
    ..writeln()
    ..writeln('## Warnings');
  if (warnings.isEmpty) {
    buffer.writeln('- None');
  } else {
    for (final warning in warnings) {
      buffer.writeln('- $warning');
    }
  }

  await File(
    '${root.path}/WISH_DATA_AUDIT_REPORT.md',
  ).writeAsString(buffer.toString());

  stdout.writeln('Wish items: ${items.length}');
  stdout.writeln('Errors: ${errors.length}');
  stdout.writeln('Warnings: ${warnings.length}');
  stdout.writeln('Report: WISH_DATA_AUDIT_REPORT.md');

  if (errors.isNotEmpty) {
    exitCode = 1;
  }
}
