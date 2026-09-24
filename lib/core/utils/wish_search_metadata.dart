/// Search-only metadata kept separate from official facility attributes.
///
/// Official attributes (DPA, indoor, thrillLevel, etc.) remain factual data.
/// These tags are curated discovery words and must not be inferred blindly
/// from a numeric attribute (for example, thrillLevel does not imply 絶叫).
class WishSearchMetadata {
  const WishSearchMetadata._();

  static const Map<String, List<String>> aliases = {
    'ビッグサンダー・マウンテン': ['big', 'big thunder', 'big thunder mountain'],
    'スペース・マウンテン': ['space', 'space mountain'],
    'スプラッシュ・マウンテン': ['splash', 'splash mountain'],
    '美女と野獣“魔法のものがたり”': ['beauty and the beast', 'beauty beast'],
    'ベイマックスのハッピーライド': ['baymax', 'happy ride'],
    'プーさんのハニーハント': ['pooh', 'pooh hunny hunt', 'hunny hunt'],
    'ソアリン：ファンタスティック・フライト': ['soaring', 'soarin'],
    'タワー・オブ・テラー': ['tower of terror', 'tower'],
    'トイ・ストーリー・マニア！': ['toy story', 'toy story mania'],
    'センター・オブ・ジ・アース': ['journey to the center of the earth', 'journey'],
    'レイジングスピリッツ': ['raging spirits', 'raging'],
    'インディ・ジョーンズ・アドベンチャー：クリスタルスカルの魔宮': ['indiana jones', 'indy'],
  };

  /// Curated semantic discovery tags. These are intentionally conservative.
  static const Map<String, List<String>> semanticTags = {
    // Tokyo Disneyland
    'ビッグサンダー・マウンテン': ['絶叫', 'コースター', 'スリル'],
    'スプラッシュ・マウンテン': ['絶叫', '落下', '水濡れ', 'スリル'],
    'スペース・マウンテン': ['絶叫', 'コースター', '暗闇', 'スリル'],
    'ベイマックスのハッピーライド': ['回転', '振り回される', 'スリル'],
    // Tokyo DisneySea
    'タワー・オブ・テラー': ['絶叫', '落下', '暗闇', 'スリル'],
    'センター・オブ・ジ・アース': ['絶叫', '急加速', 'スリル'],
    'レイジングスピリッツ': ['絶叫', 'コースター', '回転', 'スリル'],
    'インディ・ジョーンズ・アドベンチャー：クリスタルスカルの魔宮': ['スリル', '暗闇'],
  };

  static List<String> aliasesFor(String name) => aliases[name] ?? const [];
  static List<String> semanticTagsFor(String name) => semanticTags[name] ?? const [];

  static List<String> eventTagsFor(String eventPackId) {
    final id = eventPackId.toLowerCase();
    if (id.contains('halloween')) {
      return const ['ハロウィーン', 'ハロウィン', '秋', '季節限定', '期間限定', 'halloween'];
    }
    if (id.contains('christmas')) {
      return const ['クリスマス', '冬', '季節限定', '期間限定', 'christmas'];
    }
    if (id.contains('summer')) {
      return const ['夏', '夏限定', '季節限定', '期間限定', 'summer'];
    }
    if (id.contains('jubilee') || id.contains('anniversary')) {
      return const ['周年', 'アニバーサリー', '期間限定', 'anniversary'];
    }
    return const [];
  }
}
