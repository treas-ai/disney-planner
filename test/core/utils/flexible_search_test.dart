import 'package:flutter_test/flutter_test.dart';
import 'package:disney_planner/core/utils/flexible_search.dart';

void main() {
  group('FlexibleSearch', () {
    const bigThunder = <String?>[
      'ビッグサンダー・マウンテン',
      'アトラクション',
      '絶叫 スリル',
      'big big thunder big thunder mountain',
    ];

    test('ignores latin case', () {
      expect(FlexibleSearch.matches('BIG', bigThunder), isTrue);
    });

    test('matches hiragana against katakana', () {
      expect(FlexibleSearch.matches('びっぐさんだー', bigThunder), isTrue);
    });

    test('matches common romaji spellings', () {
      expect(FlexibleSearch.matches('biggusanda-', bigThunder), isTrue);
      expect(FlexibleSearch.matches('biggusannda-', bigThunder), isTrue);
      expect(FlexibleSearch.matches('biggusandaa', bigThunder), isTrue);
    });

    test('matches category and feature tags', () {
      expect(FlexibleSearch.matches('アトラクション', bigThunder), isTrue);
      expect(FlexibleSearch.matches('絶叫', bigThunder), isTrue);
    });
  });

  test('name match ranks above tag-only match', () {
    final nameScore = FlexibleSearch.score('big', ['Big Thunder Mountain', '絶叫']);
    final tagScore = FlexibleSearch.score('big', ['別の施設', 'big']);
    expect(nameScore, greaterThan(tagScore));
  });
}
