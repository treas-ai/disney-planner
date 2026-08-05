import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final files = <String>[
    'assets/master/crowd_factors/tokyo_disneyland.json',
    'assets/master/crowd_factors/tokyo_disneysea.json',
    'assets/master/wait_profiles/tokyo_disneyland.json',
    'assets/master/wait_profiles/tokyo_disneysea.json',
    'assets/master/free_drink_profiles/defaults.json',
  ];

  final errors = <String>[];
  for (final path in files) {
    final file = File(path);
    if (!await file.exists()) {
      errors.add('Missing file: $path');
      continue;
    }
    try {
      jsonDecode(await file.readAsString());
    } catch (error) {
      errors.add('Invalid JSON: $path ($error)');
    }
  }

  stdout.writeln('v5.1 data files: ${files.length}');
  stdout.writeln('Errors: ${errors.length}');
  for (final error in errors) {
    stdout.writeln('- $error');
  }

  if (errors.isNotEmpty) {
    exitCode = 1;
  }
}
