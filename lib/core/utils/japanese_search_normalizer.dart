class JapaneseSearchNormalizer {
  const JapaneseSearchNormalizer._();

  static bool matchesAny({
    required String query,
    required Iterable<String> targets,
  }) {
    final queryVariants = variants(query);

    if (queryVariants.isEmpty) {
      return true;
    }

    for (final target in targets) {
      final targetVariants = variants(target);

      for (final queryVariant in queryVariants) {
        for (final targetVariant in targetVariants) {
          if (targetVariant.contains(queryVariant)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  static Set<String> variants(String value) {
    final normalized = normalize(value);

    if (normalized.isEmpty) {
      return <String>{};
    }

    final result = <String>{normalized};

    final romaji = toRomaji(normalized);

    if (romaji.isNotEmpty) {
      result.add(romaji);
    }

    return result;
  }

  static String normalize(String value) {
    final buffer = StringBuffer();

    for (final rune in value.toLowerCase().runes) {
      final convertedRune = _normalizeRune(rune);

      if (_shouldRemove(convertedRune)) {
        continue;
      }

      buffer.writeCharCode(convertedRune);
    }

    return buffer.toString();
  }

  static int _normalizeRune(int rune) {
    // 全角英数字を半角へ変換
    if (rune >= 0xFF01 && rune <= 0xFF5E) {
      return rune - 0xFEE0;
    }

    // 全角スペース
    if (rune == 0x3000) {
      return 0x20;
    }

    // カタカナをひらがなへ変換
    if (rune >= 0x30A1 && rune <= 0x30F6) {
      return rune - 0x60;
    }

    // カタカナの繰り返し記号
    if (rune == 0x30FD) {
      return 0x309D;
    }

    if (rune == 0x30FE) {
      return 0x309E;
    }

    return rune;
  }

  static bool _shouldRemove(int rune) {
    return switch (rune) {
      0x20 => true,
      0x09 => true,
      0x0A => true,
      0x0D => true,
      0x002D => true,
      0x005F => true,
      0x002E => true,
      0x002C => true,
      0x003A => true,
      0x003B => true,
      0x002F => true,
      0x005C => true,
      0x0028 => true,
      0x0029 => true,
      0x005B => true,
      0x005D => true,
      0x007B => true,
      0x007D => true,
      0x0027 => true,
      0x0022 => true,
      0x3001 => true,
      0x3002 => true,
      0x30FB => true,
      0xFF0C => true,
      0xFF0E => true,
      0xFF1A => true,
      0xFF1B => true,
      0xFF08 => true,
      0xFF09 => true,
      0x3010 => true,
      0x3011 => true,
      0x300C => true,
      0x300D => true,
      0x300E => true,
      0x300F => true,
      0x30FC => true,
      _ => false,
    };
  }

  static String toRomaji(String value) {
    final characters = value.runes
        .map(String.fromCharCode)
        .toList(growable: false);

    final buffer = StringBuffer();

    var index = 0;
    var doubleNextConsonant = false;
    String? lastVowel;

    while (index < characters.length) {
      final current = characters[index];

      if (current == 'っ') {
        doubleNextConsonant = true;
        index++;
        continue;
      }

      if (current == 'ー') {
        if (lastVowel != null) {
          buffer.write(lastVowel);
        }

        index++;
        continue;
      }

      String? romaji;

      if (index + 1 < characters.length) {
        final pair = '$current${characters[index + 1]}';

        romaji = _digraphs[pair];

        if (romaji != null) {
          index += 2;
        }
      }

      if (romaji == null) {
        romaji = _singleKana[current];

        index++;
      }

      if (romaji == null) {
        buffer.write(current);
        doubleNextConsonant = false;
        lastVowel = null;
        continue;
      }

      if (doubleNextConsonant) {
        final consonant = _firstConsonant(romaji);

        if (consonant != null) {
          buffer.write(consonant);
        }

        doubleNextConsonant = false;
      }

      buffer.write(romaji);

      lastVowel = _lastVowel(romaji);
    }

    return buffer.toString();
  }

  static String? _firstConsonant(String value) {
    if (value.isEmpty) {
      return null;
    }

    final first = value[0];

    if ('aeiou'.contains(first)) {
      return null;
    }

    if (first == 'n') {
      return null;
    }

    return first;
  }

  static String? _lastVowel(String value) {
    for (var index = value.length - 1; index >= 0; index--) {
      final character = value[index];

      if ('aeiou'.contains(character)) {
        return character;
      }
    }

    return null;
  }

  static const Map<String, String> _digraphs = {
    'きゃ': 'kya',
    'きゅ': 'kyu',
    'きょ': 'kyo',
    'ぎゃ': 'gya',
    'ぎゅ': 'gyu',
    'ぎょ': 'gyo',
    'しゃ': 'sha',
    'しゅ': 'shu',
    'しょ': 'sho',
    'じゃ': 'ja',
    'じゅ': 'ju',
    'じょ': 'jo',
    'ちゃ': 'cha',
    'ちゅ': 'chu',
    'ちょ': 'cho',
    'にゃ': 'nya',
    'にゅ': 'nyu',
    'にょ': 'nyo',
    'ひゃ': 'hya',
    'ひゅ': 'hyu',
    'ひょ': 'hyo',
    'びゃ': 'bya',
    'びゅ': 'byu',
    'びょ': 'byo',
    'ぴゃ': 'pya',
    'ぴゅ': 'pyu',
    'ぴょ': 'pyo',
    'みゃ': 'mya',
    'みゅ': 'myu',
    'みょ': 'myo',
    'りゃ': 'rya',
    'りゅ': 'ryu',
    'りょ': 'ryo',
    'てぃ': 'ti',
    'でぃ': 'di',
    'とぅ': 'tu',
    'どぅ': 'du',
    'ふぁ': 'fa',
    'ふぃ': 'fi',
    'ふぇ': 'fe',
    'ふぉ': 'fo',
    'うぃ': 'wi',
    'うぇ': 'we',
    'うぉ': 'wo',
    'ゔぁ': 'va',
    'ゔぃ': 'vi',
    'ゔぇ': 've',
    'ゔぉ': 'vo',
    'しぇ': 'she',
    'じぇ': 'je',
    'ちぇ': 'che',
    'つぁ': 'tsa',
    'つぃ': 'tsi',
    'つぇ': 'tse',
    'つぉ': 'tso',
  };

  static const Map<String, String> _singleKana = {
    'あ': 'a',
    'い': 'i',
    'う': 'u',
    'え': 'e',
    'お': 'o',
    'か': 'ka',
    'き': 'ki',
    'く': 'ku',
    'け': 'ke',
    'こ': 'ko',
    'が': 'ga',
    'ぎ': 'gi',
    'ぐ': 'gu',
    'げ': 'ge',
    'ご': 'go',
    'さ': 'sa',
    'し': 'shi',
    'す': 'su',
    'せ': 'se',
    'そ': 'so',
    'ざ': 'za',
    'じ': 'ji',
    'ず': 'zu',
    'ぜ': 'ze',
    'ぞ': 'zo',
    'た': 'ta',
    'ち': 'chi',
    'つ': 'tsu',
    'て': 'te',
    'と': 'to',
    'だ': 'da',
    'ぢ': 'ji',
    'づ': 'zu',
    'で': 'de',
    'ど': 'do',
    'な': 'na',
    'に': 'ni',
    'ぬ': 'nu',
    'ね': 'ne',
    'の': 'no',
    'は': 'ha',
    'ひ': 'hi',
    'ふ': 'fu',
    'へ': 'he',
    'ほ': 'ho',
    'ば': 'ba',
    'び': 'bi',
    'ぶ': 'bu',
    'べ': 'be',
    'ぼ': 'bo',
    'ぱ': 'pa',
    'ぴ': 'pi',
    'ぷ': 'pu',
    'ぺ': 'pe',
    'ぽ': 'po',
    'ま': 'ma',
    'み': 'mi',
    'む': 'mu',
    'め': 'me',
    'も': 'mo',
    'や': 'ya',
    'ゆ': 'yu',
    'よ': 'yo',
    'ら': 'ra',
    'り': 'ri',
    'る': 'ru',
    'れ': 're',
    'ろ': 'ro',
    'わ': 'wa',
    'を': 'wo',
    'ん': 'n',
    'ゔ': 'vu',
    'ぁ': 'a',
    'ぃ': 'i',
    'ぅ': 'u',
    'ぇ': 'e',
    'ぉ': 'o',
    'ゃ': 'ya',
    'ゅ': 'yu',
    'ょ': 'yo',
    'ゎ': 'wa',
  };
}
