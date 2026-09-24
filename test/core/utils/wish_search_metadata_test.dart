import 'package:flutter_test/flutter_test.dart';
import 'package:disney_planner/core/utils/wish_search_metadata.dart';

void main() {
  test('Baymax is thrill but not curated as screaming ride', () {
    final tags = WishSearchMetadata.semanticTagsFor('ベイマックスのハッピーライド');
    expect(tags, contains('スリル'));
    expect(tags, isNot(contains('絶叫')));
  });

  test('curated screaming tags cover both parks', () {
    expect(WishSearchMetadata.semanticTagsFor('ビッグサンダー・マウンテン'), contains('絶叫'));
    expect(WishSearchMetadata.semanticTagsFor('タワー・オブ・テラー'), contains('絶叫'));
  });

  test('Halloween pack has seasonal discovery tags', () {
    final tags = WishSearchMetadata.eventTagsFor('halloween_2026');
    expect(tags, containsAll(['ハロウィーン', '季節限定', '期間限定']));
  });
}
