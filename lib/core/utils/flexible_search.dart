/// Lightweight, deterministic search normalization for Japanese park data.
///
/// This intentionally stays local/offline: it normalizes case, Japanese
/// scripts, punctuation and common romaji variations without calling an AI or
/// a web service.
class FlexibleSearch {
  const FlexibleSearch._();

  static bool matches(String query, Iterable<String?> fields) => score(query, fields) > 0;

  static int score(String query, Iterable<String?> fields) {
    final q = query.trim();
    if (q.isEmpty) return 1;
    final queryKeys = _keys(q);
    var best = 0;
    var fieldIndex = 0;
    for (final field in fields) {
      if (field == null || field.trim().isEmpty) { fieldIndex++; continue; }
      final fieldWeight = fieldIndex == 0 ? 300 : (fieldIndex <= 3 ? 180 : 80);
      for (final queryKey in queryKeys) {
        for (final targetKey in _keys(field)) {
          final score = targetKey == queryKey
              ? fieldWeight + 100
              : targetKey.startsWith(queryKey)
                  ? fieldWeight + 60
                  : targetKey.contains(queryKey) ? fieldWeight + 20 : 0;
          if (score > best) best = score;
        }
      }
      fieldIndex++;
    }
    return best;
  }

  static Set<String> _keys(String input) {
    final folded = _fold(input);
    final hira = _katakanaToHiragana(folded);
    final romaji = _romanize(hira);
    return <String>{
      _compact(folded),
      _compact(hira),
      _romajiCompact(romaji),
    }..removeWhere((value) => value.isEmpty);
  }

  static String _fold(String value) => value.toLowerCase().replaceAll('　', ' ');

  static String _compact(String value) => value.replaceAll(
        RegExp(r'[\s・･\-‐‑‒–—―ー_./\\,:：;；()（）\[\]【】「」『』]+'),
        '',
      );

  static String _romajiCompact(String value) {
    var result = _compact(value);
    // Common Japanese IME variations: n/nn and long-vowel spellings should
    // not prevent a hit (sanda-, sandaa, sannda- -> sanda).
    result = result.replaceAll('nn', 'n');
    result = result.replaceAllMapped(
      RegExp(r'([aeiou])\1+'),
      (match) => match.group(1)!,
    );
    return result;
  }

  static String _katakanaToHiragana(String value) {
    final out = StringBuffer();
    for (final rune in value.runes) {
      if (rune >= 0x30A1 && rune <= 0x30F6) {
        out.writeCharCode(rune - 0x60);
      } else {
        out.writeCharCode(rune);
      }
    }
    return out.toString();
  }

  static String _romanize(String value) {
    const digraph = <String, String>{
      'きゃ':'kya','きゅ':'kyu','きょ':'kyo','しゃ':'sha','しゅ':'shu','しょ':'sho',
      'ちゃ':'cha','ちゅ':'chu','ちょ':'cho','にゃ':'nya','にゅ':'nyu','にょ':'nyo',
      'ひゃ':'hya','ひゅ':'hyu','ひょ':'hyo','みゃ':'mya','みゅ':'myu','みょ':'myo',
      'りゃ':'rya','りゅ':'ryu','りょ':'ryo','ぎゃ':'gya','ぎゅ':'gyu','ぎょ':'gyo',
      'じゃ':'ja','じゅ':'ju','じょ':'jo','びゃ':'bya','びゅ':'byu','びょ':'byo',
      'ぴゃ':'pya','ぴゅ':'pyu','ぴょ':'pyo','てぃ':'ti','でぃ':'di','ふぁ':'fa',
      'ふぃ':'fi','ふぇ':'fe','ふぉ':'fo','うぃ':'wi','うぇ':'we','うぉ':'wo',
      'しぇ':'she','ちぇ':'che','じぇ':'je','つぁ':'tsa','つぃ':'tsi','つぇ':'tse','つぉ':'tso',
    };
    const mono = <String, String>{
      'あ':'a','い':'i','う':'u','え':'e','お':'o','か':'ka','き':'ki','く':'ku','け':'ke','こ':'ko',
      'さ':'sa','し':'shi','す':'su','せ':'se','そ':'so','た':'ta','ち':'chi','つ':'tsu','て':'te','と':'to',
      'な':'na','に':'ni','ぬ':'nu','ね':'ne','の':'no','は':'ha','ひ':'hi','ふ':'fu','へ':'he','ほ':'ho',
      'ま':'ma','み':'mi','む':'mu','め':'me','も':'mo','や':'ya','ゆ':'yu','よ':'yo',
      'ら':'ra','り':'ri','る':'ru','れ':'re','ろ':'ro','わ':'wa','を':'o','ん':'n',
      'が':'ga','ぎ':'gi','ぐ':'gu','げ':'ge','ご':'go','ざ':'za','じ':'ji','ず':'zu','ぜ':'ze','ぞ':'zo',
      'だ':'da','ぢ':'ji','づ':'zu','で':'de','ど':'do','ば':'ba','び':'bi','ぶ':'bu','べ':'be','ぼ':'bo',
      'ぱ':'pa','ぴ':'pi','ぷ':'pu','ぺ':'pe','ぽ':'po','ぁ':'a','ぃ':'i','ぅ':'u','ぇ':'e','ぉ':'o','ゔ':'vu',
    };
    final chars = value.runes.map(String.fromCharCode).toList();
    final out = StringBuffer();
    var geminate = false;
    for (var i = 0; i < chars.length; i++) {
      final c = chars[i];
      if (c == 'っ') { geminate = true; continue; }
      if (c == 'ー') { continue; }
      String? syllable;
      if (i + 1 < chars.length) {
        syllable = digraph['$c${chars[i + 1]}'];
        if (syllable != null) i++;
      }
      syllable ??= mono[c];
      if (syllable == null) { out.write(c); geminate = false; continue; }
      if (geminate && syllable.isNotEmpty) {
        out.write(syllable[0]);
        geminate = false;
      }
      out.write(syllable);
    }
    return out.toString();
  }
}
