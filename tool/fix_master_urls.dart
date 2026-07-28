import 'dart:convert';
import 'dart:io';

const String _westernlandPath = 'assets/master/tdl/westernland.json';

const String _westernWearId = 'tdl_westernland_western_wear';

const String _westernWearOfficialUrl =
    'https://www.tokyodisneyresort.jp/tdl/shop/detail/539/';

void main() {
  final file = File(_westernlandPath);

  if (!file.existsSync()) {
    stderr.writeln('ファイルが見つかりません：$_westernlandPath');
    exitCode = 2;
    return;
  }

  final Object? decoded;

  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    stderr.writeln('JSON形式が不正です：${error.message}');
    exitCode = 2;
    return;
  }

  if (decoded is! List) {
    stderr.writeln('JSONのルートは配列である必要があります。');
    exitCode = 2;
    return;
  }

  final facilities = decoded
      .map<Map<String, dynamic>>((item) {
        if (item is! Map) {
          throw const FormatException('配列内にJSONオブジェクトではない値があります。');
        }

        return item.map((key, value) => MapEntry(key.toString(), value));
      })
      .toList(growable: false);

  Map<String, dynamic>? westernWear;

  for (final facility in facilities) {
    if (facility['id'] == _westernWearId) {
      westernWear = facility;
      break;
    }
  }

  if (westernWear == null) {
    stderr.writeln('対象施設が見つかりません：$_westernWearId');
    exitCode = 2;
    return;
  }

  final oldUrl = westernWear['officialUrl'];

  if (oldUrl == _westernWearOfficialUrl) {
    stdout.writeln('ウエスタンウエアのURLは既に修正済みです。');
    return;
  }

  westernWear['officialUrl'] = _westernWearOfficialUrl;

  const encoder = JsonEncoder.withIndent('  ');

  file.writeAsStringSync('${encoder.convert(facilities)}\n');

  stdout.writeln('ウエスタンウエアの公式URLを修正しました。');
  stdout.writeln('変更前：$oldUrl');
  stdout.writeln('変更後：$_westernWearOfficialUrl');
}
