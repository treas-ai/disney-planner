import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'classifier_models.dart';
import 'facility_classifier.dart';
import 'migration_report.dart';

Future<void> main(List<String> arguments) async {
  final options = MigrationOptions.parse(arguments);

  if (options.showHelp) {
    _printHelp();
    return;
  }

  final runner = MasterDataMigrationRunner(options: options);

  try {
    final result = await runner.run();

    stdout.writeln();
    stdout.writeln('マスターデータ移行処理が完了しました。');
    stdout.writeln(
      '実行モード：'
      '${result.summary.dryRun ? 'ドライラン' : '書き込み'}',
    );
    stdout.writeln(
      '対象ファイル数：'
      '${result.summary.fileCount}',
    );
    stdout.writeln(
      '対象施設数：'
      '${result.summary.facilityCount}',
    );
    stdout.writeln(
      '変更施設数：'
      '${result.summary.changedFacilityCount}',
    );
    stdout.writeln(
      '手動確認対象：'
      '${result.summary.manualReviewCount}',
    );
    stdout.writeln(
      'テキストレポート：'
      '${result.reportOutput.textReportPath}',
    );
    stdout.writeln(
      'JSONレポート：'
      '${result.reportOutput.jsonReportPath}',
    );

    if (result.backupDirectoryPath != null) {
      stdout.writeln(
        'バックアップ：'
        '${result.backupDirectoryPath}',
      );
    }

    if (result.summary.dryRun) {
      stdout.writeln();
      stdout.writeln('JSONファイルは変更されていません。');
      stdout.writeln(
        '内容を確認後、'
        '`--write`を付けて再実行してください。',
      );
    }

    if (result.summary.manualReviewCount > 0) {
      stdout.writeln();
      stdout.writeln('手動確認が必要な施設があります。');
      stdout.writeln('migration_report.txtを確認してください。');
    }
  } on MigrationUsageException catch (error) {
    stderr.writeln('引数エラー：${error.message}');
    stderr.writeln();
    _printHelp();
    exitCode = 64;
  } on MigrationExecutionException catch (error) {
    stderr.writeln('移行処理に失敗しました。');
    stderr.writeln(error.message);

    if (error.cause != null) {
      stderr.writeln('原因：${error.cause}');
    }

    exitCode = 1;
  } catch (error, stackTrace) {
    stderr.writeln('予期しないエラーが発生しました。');
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

class MasterDataMigrationRunner {
  const MasterDataMigrationRunner({
    required this.options,
    this.classifier = const FacilityClassifier(),
    this.reportWriter = const MigrationReportWriter(),
  });

  final MigrationOptions options;
  final FacilityClassifier classifier;
  final MigrationReportWriter reportWriter;

  Future<MasterDataMigrationRunResult> run() async {
    final startedAt = DateTime.now();

    final projectDirectory = Directory(
      path.normalize(path.absolute(options.projectRootPath)),
    );

    if (!await projectDirectory.exists()) {
      throw MigrationExecutionException(
        'プロジェクトルートが存在しません：'
        '${projectDirectory.path}',
      );
    }

    final masterDirectory = Directory(
      path.join(projectDirectory.path, options.masterDataPath),
    );

    if (!await masterDirectory.exists()) {
      throw MigrationExecutionException(
        'マスターデータフォルダが'
        '存在しません：'
        '${masterDirectory.path}',
      );
    }

    final outputDirectory = Directory(
      path.join(projectDirectory.path, options.outputPath),
    );

    await outputDirectory.create(recursive: true);

    final facilityFiles = await _discoverFacilityFiles(
      projectDirectory: projectDirectory,
      masterDirectory: masterDirectory,
    );

    if (facilityFiles.isEmpty) {
      throw MigrationExecutionException(
        '施設マスターデータJSONが'
        '見つかりませんでした。',
      );
    }

    stdout.writeln(
      '対象ファイルを'
      '${facilityFiles.length}件検出しました。',
    );

    final backupDirectory = await _prepareBackupDirectory(
      projectDirectory: projectDirectory,
      startedAt: startedAt,
    );

    final fileResults = <MigrationFileResult>[];

    for (final file in facilityFiles) {
      final result = await _processFile(
        projectDirectory: projectDirectory,
        file: file,
        backupDirectory: backupDirectory,
      );

      fileResults.add(result);
    }

    final finishedAt = DateTime.now();

    final summary = MigrationSummary(
      startedAt: startedAt,
      finishedAt: finishedAt,
      files: List<MigrationFileResult>.unmodifiable(fileResults),
      dryRun: options.dryRun,
    );

    final reportOutput = await reportWriter.write(
      summary: summary,
      outputDirectory: outputDirectory,
    );

    return MasterDataMigrationRunResult(
      summary: summary,
      reportOutput: reportOutput,
      backupDirectoryPath: backupDirectory?.path,
    );
  }

  Future<List<File>> _discoverFacilityFiles({
    required Directory projectDirectory,
    required Directory masterDirectory,
  }) async {
    final manifestFiles = await _readManifestFacilityFiles(
      projectDirectory: projectDirectory,
      masterDirectory: masterDirectory,
    );

    if (manifestFiles.isNotEmpty) {
      return manifestFiles;
    }

    stdout.writeln(
      'manifestから施設ファイルを'
      '取得できなかったため、'
      'assets/master配下を検索します。',
    );

    final discoveredFiles = <File>[];

    await for (final entity in masterDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }

      if (path.extension(entity.path).toLowerCase() != '.json') {
        continue;
      }

      if (_isExcludedJsonFile(entity.path)) {
        continue;
      }

      if (await _isFacilityJsonFile(entity)) {
        discoveredFiles.add(entity);
      }
    }

    discoveredFiles.sort((first, second) => first.path.compareTo(second.path));

    return discoveredFiles;
  }

  Future<List<File>> _readManifestFacilityFiles({
    required Directory projectDirectory,
    required Directory masterDirectory,
  }) async {
    final manifestFile = File(
      path.join(masterDirectory.path, 'master_manifest.json'),
    );

    if (!await manifestFile.exists()) {
      return <File>[];
    }

    try {
      final decoded = jsonDecode(await manifestFile.readAsString());

      if (decoded is! Map) {
        return <File>[];
      }

      final rawFacilityFiles = decoded['facilityFiles'];

      if (rawFacilityFiles is! List) {
        return <File>[];
      }

      final result = <File>[];
      final usedPaths = <String>{};

      for (final value in rawFacilityFiles) {
        if (value is! String || value.trim().isEmpty) {
          continue;
        }

        final resolvedPath = _resolveManifestPath(
          projectDirectory: projectDirectory,
          masterDirectory: masterDirectory,
          manifestValue: value.trim(),
        );

        final normalizedPath = path.normalize(path.absolute(resolvedPath));

        if (!usedPaths.add(normalizedPath)) {
          continue;
        }

        final file = File(normalizedPath);

        if (!await file.exists()) {
          throw MigrationExecutionException(
            'manifestに記載された'
            '施設ファイルが存在しません：'
            '$value',
          );
        }

        result.add(file);
      }

      result.sort((first, second) => first.path.compareTo(second.path));

      return result;
    } on FormatException catch (error) {
      throw MigrationExecutionException(
        'master_manifest.jsonの'
        'JSON形式が正しくありません。',
        cause: error,
      );
    }
  }

  String _resolveManifestPath({
    required Directory projectDirectory,
    required Directory masterDirectory,
    required String manifestValue,
  }) {
    if (path.isAbsolute(manifestValue)) {
      return manifestValue;
    }

    final normalizedValue = path.normalize(manifestValue);

    if (normalizedValue == 'assets' ||
        path.split(normalizedValue).first == 'assets') {
      return path.join(projectDirectory.path, normalizedValue);
    }

    return path.join(masterDirectory.path, normalizedValue);
  }

  bool _isExcludedJsonFile(String filePath) {
    final fileName = path.basename(filePath);

    const excludedNames = {
      'master_manifest.json',
      'parks.json',
      'areas.json',
      'migration_report.json',
    };

    return excludedNames.contains(fileName);
  }

  Future<bool> _isFacilityJsonFile(File file) async {
    try {
      final decoded = jsonDecode(await file.readAsString());

      if (decoded is! List || decoded.isEmpty) {
        return false;
      }

      for (final row in decoded) {
        if (row is Map &&
            row['id'] is String &&
            row['name'] is String &&
            row['category'] is String &&
            row['parkId'] is String &&
            row['areaId'] is String) {
          return true;
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<MigrationFileResult> _processFile({
    required Directory projectDirectory,
    required File file,
    required Directory? backupDirectory,
  }) async {
    final relativeAssetPath = _toRelativeAssetPath(
      projectDirectory: projectDirectory,
      file: file,
    );

    stdout.writeln('処理中：$relativeAssetPath');

    final sourceText = await file.readAsString();

    final rows = _decodeFacilityRows(
      sourceText: sourceText,
      assetPath: relativeAssetPath,
    );

    final records = classifier.migrateAll(
      assetPath: relativeAssetPath,
      rows: rows,
    );

    final changed = records.any((record) => record.wasChanged);

    var wasWritten = false;

    if (changed && !options.dryRun) {
      if (backupDirectory != null) {
        await _backupFile(
          projectDirectory: projectDirectory,
          sourceFile: file,
          backupDirectory: backupDirectory,
        );
      }

      final migratedRows = records
          .map((record) => record.after)
          .toList(growable: false);

      await _writeJsonAtomically(file: file, value: migratedRows);

      wasWritten = true;
    }

    stdout.writeln(
      '  施設数：${records.length}'
      ' / 変更：'
      '${records.where((record) => record.wasChanged).length}'
      ' / 手動確認：'
      '${records.where((record) => record.requiresManualReview).length}',
    );

    return MigrationFileResult(
      assetPath: relativeAssetPath,
      records: List<FacilityMigrationRecord>.unmodifiable(records),
      wasWritten: wasWritten,
    );
  }

  List<Map<String, dynamic>> _decodeFacilityRows({
    required String sourceText,
    required String assetPath,
  }) {
    dynamic decoded;

    try {
      decoded = jsonDecode(sourceText);
    } on FormatException catch (error) {
      throw MigrationExecutionException(
        '$assetPathのJSON形式が'
        '正しくありません。',
        cause: error,
      );
    }

    if (decoded is! List) {
      throw MigrationExecutionException(
        '$assetPathのルート要素は'
        '配列である必要があります。',
      );
    }

    final rows = <Map<String, dynamic>>[];

    for (var index = 0; index < decoded.length; index++) {
      final value = decoded[index];

      if (value is! Map) {
        throw MigrationExecutionException(
          '$assetPath[$index]が'
          'JSONオブジェクトではありません。',
        );
      }

      final converted = <String, dynamic>{};

      for (final entry in value.entries) {
        converted[entry.key.toString()] = entry.value;
      }

      rows.add(converted);
    }

    return rows;
  }

  Future<Directory?> _prepareBackupDirectory({
    required Directory projectDirectory,
    required DateTime startedAt,
  }) async {
    if (options.dryRun || !options.createBackup) {
      return null;
    }

    final timestamp = _buildTimestamp(startedAt);

    final backupDirectory = Directory(
      path.join(
        projectDirectory.path,
        options.outputPath,
        'backups',
        timestamp,
      ),
    );

    await backupDirectory.create(recursive: true);

    return backupDirectory;
  }

  Future<void> _backupFile({
    required Directory projectDirectory,
    required File sourceFile,
    required Directory backupDirectory,
  }) async {
    final relativePath = path.relative(
      sourceFile.path,
      from: projectDirectory.path,
    );

    final backupFile = File(path.join(backupDirectory.path, relativePath));

    await backupFile.parent.create(recursive: true);

    await sourceFile.copy(backupFile.path);
  }

  Future<void> _writeJsonAtomically({
    required File file,
    required Object? value,
  }) async {
    final formattedJson = const JsonEncoder.withIndent('  ').convert(value);

    final temporaryFile = File('${file.path}.migration_tmp');

    try {
      await temporaryFile.writeAsString('$formattedJson\n', flush: true);

      final verificationText = await temporaryFile.readAsString();

      jsonDecode(verificationText);

      if (Platform.isWindows) {
        await file.writeAsString(verificationText, flush: true);

        await temporaryFile.delete();
      } else {
        await temporaryFile.rename(file.path);
      }
    } catch (error) {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }

      throw MigrationExecutionException(
        'JSONファイルの書き込みに'
        '失敗しました：${file.path}',
        cause: error,
      );
    }
  }

  String _toRelativeAssetPath({
    required Directory projectDirectory,
    required File file,
  }) {
    return path
        .relative(file.path, from: projectDirectory.path)
        .replaceAll(Platform.pathSeparator, '/');
  }

  String _buildTimestamp(DateTime value) {
    final local = value.toLocal();

    return '${local.year.toString().padLeft(4, '0')}'
        '${local.month.toString().padLeft(2, '0')}'
        '${local.day.toString().padLeft(2, '0')}_'
        '${local.hour.toString().padLeft(2, '0')}'
        '${local.minute.toString().padLeft(2, '0')}'
        '${local.second.toString().padLeft(2, '0')}';
  }
}

class MigrationOptions {
  const MigrationOptions({
    required this.projectRootPath,
    required this.masterDataPath,
    required this.outputPath,
    required this.dryRun,
    required this.createBackup,
    required this.showHelp,
  });

  final String projectRootPath;
  final String masterDataPath;
  final String outputPath;
  final bool dryRun;
  final bool createBackup;
  final bool showHelp;

  factory MigrationOptions.parse(List<String> arguments) {
    var projectRootPath = Directory.current.path;

    var masterDataPath = path.join('assets', 'master');

    var outputPath = path.join('tool', 'master_data', 'output');

    var dryRun = true;
    var createBackup = true;
    var showHelp = false;

    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];

      switch (argument) {
        case '--help':
        case '-h':
          showHelp = true;

        case '--dry-run':
          dryRun = true;

        case '--write':
          dryRun = false;

        case '--no-backup':
          createBackup = false;

        case '--backup':
          createBackup = true;

        case '--project-root':
          projectRootPath = _readOptionValue(
            arguments: arguments,
            currentIndex: index,
            optionName: '--project-root',
          );

          index++;

        case '--master-data':
          masterDataPath = _readOptionValue(
            arguments: arguments,
            currentIndex: index,
            optionName: '--master-data',
          );

          index++;

        case '--output':
          outputPath = _readOptionValue(
            arguments: arguments,
            currentIndex: index,
            optionName: '--output',
          );

          index++;

        default:
          if (argument.startsWith('--project-root=')) {
            projectRootPath = argument.substring('--project-root='.length);
          } else if (argument.startsWith('--master-data=')) {
            masterDataPath = argument.substring('--master-data='.length);
          } else if (argument.startsWith('--output=')) {
            outputPath = argument.substring('--output='.length);
          } else {
            throw MigrationUsageException('不明な引数です：$argument');
          }
      }
    }

    return MigrationOptions(
      projectRootPath: projectRootPath,
      masterDataPath: masterDataPath,
      outputPath: outputPath,
      dryRun: dryRun,
      createBackup: createBackup,
      showHelp: showHelp,
    );
  }

  static String _readOptionValue({
    required List<String> arguments,
    required int currentIndex,
    required String optionName,
  }) {
    final valueIndex = currentIndex + 1;

    if (valueIndex >= arguments.length) {
      throw MigrationUsageException('$optionNameの値がありません。');
    }

    final value = arguments[valueIndex];

    if (value.startsWith('--')) {
      throw MigrationUsageException('$optionNameの値がありません。');
    }

    return value;
  }
}

class MasterDataMigrationRunResult {
  const MasterDataMigrationRunResult({
    required this.summary,
    required this.reportOutput,
    required this.backupDirectoryPath,
  });

  final MigrationSummary summary;

  final MigrationReportOutput reportOutput;

  final String? backupDirectoryPath;
}

class MigrationUsageException implements Exception {
  const MigrationUsageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MigrationExecutionException implements Exception {
  const MigrationExecutionException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) {
      return message;
    }

    return '$message\n$cause';
  }
}

void _printHelp() {
  stdout.writeln(
    'Disney Planner '
    'マスターデータ移行ツール',
  );

  stdout.writeln();
  stdout.writeln('使用方法：');

  stdout.writeln(
    '  dart run '
    'tool/master_data/'
    'migrate_master_data.dart '
    '[オプション]',
  );

  stdout.writeln();
  stdout.writeln('オプション：');

  stdout.writeln('  --dry-run');
  stdout.writeln(
    '      JSONを書き換えず、'
    '分類結果とレポートだけを生成します。',
  );
  stdout.writeln('      省略時の既定値です。');

  stdout.writeln();
  stdout.writeln('  --write');
  stdout.writeln(
    '      JSONファイルへ'
    '分類結果を書き込みます。',
  );

  stdout.writeln();
  stdout.writeln('  --backup');
  stdout.writeln(
    '      書き込み前に'
    'バックアップを作成します。',
  );
  stdout.writeln('      既定で有効です。');

  stdout.writeln();
  stdout.writeln('  --no-backup');
  stdout.writeln('      バックアップを作成しません。');

  stdout.writeln();
  stdout.writeln('  --project-root <パス>');
  stdout.writeln(
    '      Flutterプロジェクトの'
    'ルートフォルダを指定します。',
  );
  stdout.writeln('      既定値は現在のフォルダです。');

  stdout.writeln();
  stdout.writeln('  --master-data <パス>');
  stdout.writeln(
    '      プロジェクトルートから見た'
    'マスターデータフォルダを指定します。',
  );
  stdout.writeln('      既定値：assets/master');

  stdout.writeln();
  stdout.writeln('  --output <パス>');
  stdout.writeln(
    '      レポートとバックアップの'
    '出力先を指定します。',
  );
  stdout.writeln(
    '      既定値：'
    'tool/master_data/output',
  );

  stdout.writeln();
  stdout.writeln('  --help, -h');
  stdout.writeln('      このヘルプを表示します。');

  stdout.writeln();
  stdout.writeln('実行例：');

  stdout.writeln(
    '  dart run '
    'tool/master_data/'
    'migrate_master_data.dart '
    '--dry-run',
  );

  stdout.writeln();

  stdout.writeln(
    '  dart run '
    'tool/master_data/'
    'migrate_master_data.dart '
    '--write',
  );
}
