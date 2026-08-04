import 'dart:convert';

class SharePayloadCodec {
  const SharePayloadCodec();

  static const String _codePrefix = 'DP4.';
  static const String _shareBaseUrl = 'https://disney-planner.local/import';

  String encodeBackupLink(String backupJson) {
    return _encodeLink(
      jsonEncode({
        'shareSchemaVersion': 1,
        'kind': 'backup',
        'payload': jsonDecode(backupJson),
      }),
    );
  }

  String encodePlanLink(String planJson) {
    return _encodeLink(planJson);
  }

  String encodeRawCode(String json) {
    final encoded = base64UrlEncode(utf8.encode(json)).replaceAll('=', '');
    return '$_codePrefix$encoded';
  }

  Map<String, dynamic> decode(String input) {
    var value = input.trim();
    if (value.isEmpty) {
      throw const FormatException('共有データが入力されていません。');
    }

    if (value.startsWith('{')) {
      return _decodeMap(value);
    }

    final uri = Uri.tryParse(value);
    if (uri != null) {
      if (uri.fragment.startsWith(_codePrefix)) {
        value = uri.fragment;
      } else if (uri.queryParameters['data'] case final String data) {
        value = data;
      }
    }

    final prefixIndex = value.indexOf(_codePrefix);
    if (prefixIndex >= 0) {
      value = value.substring(prefixIndex);
    }

    if (!value.startsWith(_codePrefix)) {
      throw const FormatException('Disney Plannerの共有URL・共有コード・JSONではありません。');
    }

    final encoded = value.substring(_codePrefix.length);
    final normalized = encoded.padRight(
      encoded.length + ((4 - encoded.length % 4) % 4),
      '=',
    );

    try {
      final json = utf8.decode(base64Url.decode(normalized));
      return _decodeMap(json);
    } catch (_) {
      throw const FormatException('共有コードが壊れているか、途中で切れています。');
    }
  }

  String _encodeLink(String json) {
    final code = encodeRawCode(json);
    return '$_shareBaseUrl#$code';
  }

  Map<String, dynamic> _decodeMap(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw const FormatException('共有データの形式が正しくありません。');
    }
    return {
      for (final entry in decoded.entries) entry.key.toString(): entry.value,
    };
  }
}
