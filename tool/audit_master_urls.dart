import 'dart:convert';
import 'dart:io';

const String _masterDirectoryPath = 'assets/master/tdl';

const String _officialHost = 'www.tokyodisneyresort.jp';

const String _bibbidiBobbidiBoutiqueId =
    'tdl_world_bazaar_bibbidi_bobbidi_boutique';

const String _gagFactoryId = 'tdl_toontown_gag_factory_five_and_dime';

const String _gagFactoryCapsuleToyId = 'tdl_toontown_gag_factory_capsule_toy';

void main() {
  final directory = Directory(_masterDirectoryPath);

  if (!directory.existsSync()) {
    stderr.writeln(
      '監査対象フォルダーが見つかりません：'
      '$_masterDirectoryPath',
    );
    exitCode = 2;
    return;
  }

  final files =
      directory
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.json'))
          .toList(growable: false)
        ..sort((left, right) => left.path.compareTo(right.path));

  final report = _AuditReport();

  for (final file in files) {
    _auditFile(file, report);
  }

  _auditDuplicateUrls(report);
  _printReport(report);

  if (report.errors.isNotEmpty) {
    exitCode = 1;
  }
}

void _auditFile(File file, _AuditReport report) {
  final filePath = _normalizePath(file.path);

  Object? decoded;

  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    report.errors.add(
      _Finding(location: filePath, message: 'JSON形式が不正です：${error.message}'),
    );
    return;
  } on FileSystemException catch (error) {
    report.errors.add(
      _Finding(
        location: filePath,
        message:
            'ファイルを読み込めません：'
            '${error.message}',
      ),
    );
    return;
  }

  if (decoded is! List) {
    report.errors.add(
      _Finding(location: filePath, message: 'JSONのルートは配列である必要があります。'),
    );
    return;
  }

  report.fileCount++;

  for (var index = 0; index < decoded.length; index++) {
    final item = decoded[index];

    if (item is! Map) {
      report.errors.add(
        _Finding(location: '$filePath[$index]', message: 'JSONオブジェクトではありません。'),
      );
      continue;
    }

    final row = item.map((key, value) => MapEntry(key.toString(), value));

    _auditFacility(row: row, filePath: filePath, index: index, report: report);
  }
}

void _auditFacility({
  required Map<String, dynamic> row,
  required String filePath,
  required int index,
  required _AuditReport report,
}) {
  report.facilityCount++;

  final id = _readNullableString(row['id']);

  final name = _readNullableString(row['name']) ?? id ?? 'インデックス$index';

  final category = _readNullableString(row['category']);

  final shopType = _readNullableString(row['shopType']) ?? 'none';

  final officialUrl = _validateUrl(
    value: row['officialUrl'],
    fieldName: 'officialUrl',
    filePath: filePath,
    facilityId: id,
    facilityName: name,
    report: report,
  );

  final menuUrl = _validateUrl(
    value: row['menuUrl'],
    fieldName: 'menuUrl',
    filePath: filePath,
    facilityId: id,
    facilityName: name,
    report: report,
  );

  if (officialUrl == null) {
    report.missingOfficialUrlCount++;

    report.warnings.add(
      _Finding(
        location: '$filePath / $name / officialUrl',
        message: '公式URLが未設定です。',
      ),
    );
  } else {
    report.officialUrlCount++;

    _validateOfficialUrlPath(
      uri: officialUrl,
      facilityId: id,
      category: category,
      filePath: filePath,
      facilityName: name,
      report: report,
    );

    report.urlUsages.add(
      _UrlUsage(
        url: officialUrl.toString(),
        facilityId: id,
        facilityName: name,
        filePath: filePath,
        fieldName: 'officialUrl',
        shopType: shopType,
      ),
    );
  }

  if (menuUrl != null) {
    report.menuUrlCount++;

    _validateMenuUrl(
      uri: menuUrl,
      category: category,
      filePath: filePath,
      facilityId: id,
      facilityName: name,
      report: report,
    );

    report.urlUsages.add(
      _UrlUsage(
        url: menuUrl.toString(),
        facilityId: id,
        facilityName: name,
        filePath: filePath,
        fieldName: 'menuUrl',
        shopType: shopType,
      ),
    );
  }

  if (category == 'restaurant' && menuUrl == null) {
    report.missingRestaurantMenuUrlCount++;

    report.warnings.add(
      _Finding(
        location: '$filePath / $name / menuUrl',
        message:
            'レストランですが'
            'メニューURLが未設定です。',
      ),
    );
  }
}

Uri? _validateUrl({
  required Object? value,
  required String fieldName,
  required String filePath,
  required String? facilityId,
  required String facilityName,
  required _AuditReport report,
}) {
  if (value == null) {
    return null;
  }

  final location = '$filePath / $facilityName / $fieldName';

  if (value is! String) {
    report.errors.add(
      _Finding(
        location: location,
        message:
            'URLは文字列またはnullで'
            '指定してください。',
      ),
    );
    return null;
  }

  final source = value.trim();

  if (source.isEmpty) {
    report.errors.add(
      _Finding(
        location: location,
        message:
            '空文字ではなくnullを'
            '使用してください。',
      ),
    );
    return null;
  }

  final uri = Uri.tryParse(source);

  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    report.errors.add(
      _Finding(location: location, message: 'URL形式が不正です：$source'),
    );
    return null;
  }

  if (uri.scheme != 'https') {
    report.errors.add(
      _Finding(location: location, message: 'HTTPSを使用してください：$source'),
    );
  }

  if (uri.host != _officialHost) {
    report.errors.add(
      _Finding(
        location: location,
        message:
            '公式ドメインではありません：'
            '${uri.host}',
      ),
    );
  }

  if (uri.pathSegments.map((segment) => segment.toLowerCase()).contains('en')) {
    report.errors.add(
      _Finding(
        location: location,
        message:
            '英語版URLが設定されています：'
            '$source',
      ),
    );
  }

  final isLandUrl = uri.path.startsWith('/tdl/');

  final isSpecialOfficialUrl = uri.path.startsWith('/happy/bbb/');

  if (!isLandUrl && !isSpecialOfficialUrl) {
    report.errors.add(
      _Finding(
        location: location,
        message:
            '東京ディズニーランド関連の'
            '公式URLではありません：$source',
      ),
    );
  }

  return uri;
}

void _validateOfficialUrlPath({
  required Uri uri,
  required String? facilityId,
  required String? category,
  required String filePath,
  required String facilityName,
  required _AuditReport report,
}) {
  final location = '$filePath / $facilityName / officialUrl';

  // ビビディ・バビディ・ブティックは
  // アプリ上ではservice扱いだが、
  // 公式サイトではshop/detail配下に掲載されている。
  if (facilityId == _bibbidiBobbidiBoutiqueId) {
    const expectedPath = '/tdl/shop/detail/566/';

    if (uri.path != expectedPath) {
      report.errors.add(
        _Finding(
          location: location,
          message:
              'ビビディ・バビディ・'
              'ブティックの公式URLが'
              '一致しません。'
              ' 期待：$expectedPath'
              ' 実際：${uri.path}',
        ),
      );
    }

    return;
  }

  final expectedPrefix = switch (category) {
    'attraction' => '/tdl/attraction/',
    'restaurant' => '/tdl/restaurant/',
    'shop' => '/tdl/shop/',
    'show' => '/tdl/show/',
    'parade' => '/tdl/show/',
    'greeting' => '/tdl/greeting/',
    'service' => '/tdl/service/',
    _ => null,
  };

  if (expectedPrefix == null) {
    report.warnings.add(
      _Finding(
        location: location,
        message:
            'URL種別を監査できない'
            'カテゴリです：$category',
      ),
    );
    return;
  }

  if (!uri.path.startsWith(expectedPrefix)) {
    report.errors.add(
      _Finding(
        location: location,
        message:
            'カテゴリ「$category」に対して'
            'URL種別が一致しません。'
            ' 期待：$expectedPrefix'
            ' 実際：${uri.path}',
      ),
    );
  }

  if (!uri.path.contains('/detail/')) {
    report.warnings.add(
      _Finding(
        location: location,
        message:
            '施設詳細ページではない'
            '可能性があります：${uri.path}',
      ),
    );
  }
}

void _validateMenuUrl({
  required Uri uri,
  required String? category,
  required String filePath,
  required String? facilityId,
  required String facilityName,
  required _AuditReport report,
}) {
  final location = '$filePath / $facilityName / menuUrl';

  if (category != 'restaurant') {
    report.errors.add(
      _Finding(
        location: location,
        message:
            'レストラン以外に'
            'メニューURLが設定されています。',
      ),
    );
  }

  const expectedPrefix = '/tdl/restaurant/food/';

  if (!uri.path.startsWith(expectedPrefix)) {
    report.errors.add(
      _Finding(
        location: location,
        message:
            'メニューURLの形式が'
            '一致しません。'
            ' 期待：$expectedPrefix'
            ' 実際：${uri.path}',
      ),
    );
  }
}

void _auditDuplicateUrls(_AuditReport report) {
  final usagesByUrl = <String, List<_UrlUsage>>{};

  for (final usage in report.urlUsages) {
    usagesByUrl.putIfAbsent(usage.url, () => <_UrlUsage>[]).add(usage);
  }

  for (final entry in usagesByUrl.entries) {
    if (entry.value.length <= 1) {
      continue;
    }

    final facilityIds = entry.value
        .map((usage) => usage.facilityId)
        .whereType<String>()
        .toSet();

    if (facilityIds.length <= 1) {
      continue;
    }

    if (_isAllowedGagFactoryDuplicate(facilityIds)) {
      continue;
    }

    final details = entry.value
        .map(
          (usage) =>
              '${usage.facilityName}'
              '（${usage.fieldName}・'
              '${usage.filePath}）',
        )
        .join(' / ');

    report.warnings.add(
      _Finding(
        location: '複数ファイル',
        message:
            '同一URLが複数施設で'
            '使用されています：'
            '${entry.key}\n  $details',
      ),
    );
  }
}

bool _isAllowedGagFactoryDuplicate(Set<String> facilityIds) {
  return facilityIds.length == 2 &&
      facilityIds.contains(_gagFactoryId) &&
      facilityIds.contains(_gagFactoryCapsuleToyId);
}

void _printReport(_AuditReport report) {
  stdout.writeln('');
  stdout.writeln('========================================');
  stdout.writeln('東京ディズニーランド 公式URL監査結果');
  stdout.writeln('========================================');
  stdout.writeln('対象ファイル数：${report.fileCount}');
  stdout.writeln('対象施設数　　：${report.facilityCount}');
  stdout.writeln('公式URL設定数 ：${report.officialUrlCount}');
  stdout.writeln('メニューURL数 ：${report.menuUrlCount}');
  stdout.writeln(
    '公式URL未設定 ：'
    '${report.missingOfficialUrlCount}',
  );
  stdout.writeln(
    'レストランのメニューURL未設定：'
    '${report.missingRestaurantMenuUrlCount}',
  );
  stdout.writeln('エラー件数　　：${report.errors.length}');
  stdout.writeln('警告件数　　　：${report.warnings.length}');

  if (report.errors.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('【エラー】');

    for (var index = 0; index < report.errors.length; index++) {
      _printFinding(index + 1, report.errors[index]);
    }
  }

  if (report.warnings.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('【警告】');

    for (var index = 0; index < report.warnings.length; index++) {
      _printFinding(index + 1, report.warnings[index]);
    }
  }

  stdout.writeln('');

  if (report.errors.isEmpty && report.warnings.isEmpty) {
    stdout.writeln('公式URLの構造上の問題はありません。');
  } else if (report.errors.isEmpty) {
    stdout.writeln(
      'エラーはありません。'
      '警告内容を確認してください。',
    );
  } else {
    stdout.writeln(
      'エラーを修正してから'
      '再度監査してください。',
    );
  }
}

void _printFinding(int index, _Finding finding) {
  stdout.writeln('$index. ${finding.location}');
  stdout.writeln('   ${finding.message}');
}

String? _readNullableString(Object? value) {
  if (value is! String) {
    return null;
  }

  final trimmed = value.trim();

  return trimmed.isEmpty ? null : trimmed;
}

String _normalizePath(String source) {
  return source.replaceAll('\\', '/');
}

class _AuditReport {
  int fileCount = 0;
  int facilityCount = 0;
  int officialUrlCount = 0;
  int menuUrlCount = 0;
  int missingOfficialUrlCount = 0;
  int missingRestaurantMenuUrlCount = 0;

  final List<_Finding> errors = [];
  final List<_Finding> warnings = [];
  final List<_UrlUsage> urlUsages = [];
}

class _Finding {
  const _Finding({required this.location, required this.message});

  final String location;
  final String message;
}

class _UrlUsage {
  const _UrlUsage({
    required this.url,
    required this.facilityId,
    required this.facilityName,
    required this.filePath,
    required this.fieldName,
    required this.shopType,
  });

  final String url;
  final String? facilityId;
  final String facilityName;
  final String filePath;
  final String fieldName;
  final String shopType;
}
