import 'classifier_models.dart';

class ShopClassifier {
  const ShopClassifier();

  static const Set<String> _allowedShopTypes = {
    'general',
    'capsuleToy',
    'apparel',
    'confectionery',
    'souvenir',
    'specialty',
    'limited',
    'photoService',
  };

  static const Map<String, String> _exactTypeByName = {
    'グランドエンポーリアム': 'general',
    'ホームストア': 'general',
    'ボン・ヴォヤージュ': 'general',

    'タウンセンターファッション': 'apparel',
    'フィガロズ・クロージアー': 'apparel',

    'ワールドバザール・コンフェクショナリー': 'confectionery',
    'ヴァレンティーナズ・スウィート': 'confectionery',
    'ペイストリーパレス': 'confectionery',

    'トイ・ステーション': 'specialty',
    'ハウス・オブ・グリーティング': 'specialty',
    'ディズニー＆カンパニー': 'specialty',
    'ギャグファクトリー／ファイブ・アンド・ダイム': 'specialty',
    'シルエットスタジオ': 'specialty',
    'ハリントンズ・ジュエリー＆ウォッチ': 'specialty',
    'マジックショップ': 'specialty',

    'カメラセンター': 'photoService',
    'フォトグラフィカ': 'photoService',
  };

  static const Set<String> _knownCapsuleToyNames = {
    'トレジャーコメット',
    'ギャグファクトリー／ファイブ・アンド・ダイム',
    'マーメイドトレジャー',
  };

  ShopClassification classify(FacilitySource source) {
    if (source.facilityType != FacilityMigrationType.shop) {
      return ShopClassification(
        shopType: 'none',
        supportsStandbyPass: false,
        confidence: ClassificationConfidence.unknown,
        reason: 'ショップ以外の施設がShopClassifierへ渡されました。',
        matchedRule: 'invalid_category',
      );
    }

    final existingType = _normalizeExistingType(source.shopType);

    if (existingType != null) {
      return ShopClassification(
        shopType: existingType,
        supportsStandbyPass: _resolveStandbyPass(
          source: source,
          shopType: existingType,
        ),
        confidence: ClassificationConfidence.exact,
        reason: '既存のshopTypeが有効なため、その値を維持しました。',
        matchedRule: 'existing_shop_type',
      );
    }

    final normalizedName = _normalizeName(source.name);

    if (_isKnownCapsuleToyName(normalizedName)) {
      return ShopClassification(
        shopType: 'capsuleToy',
        supportsStandbyPass: _resolveStandbyPass(
          source: source,
          shopType: 'capsuleToy',
        ),
        confidence: ClassificationConfidence.high,
        reason: 'カプセルトイ取扱施設の既知リストに一致したため、カプセルトイに分類しました。',
        matchedRule: 'known_capsule_toy_name',
      );
    }

    final exactType = _findExactType(normalizedName);

    if (exactType != null) {
      return ShopClassification(
        shopType: exactType,
        supportsStandbyPass: _resolveStandbyPass(
          source: source,
          shopType: exactType,
        ),
        confidence: ClassificationConfidence.exact,
        reason: '施設名の完全一致ルールからショップ種別を判定しました。',
        matchedRule: 'exact_name:$exactType',
      );
    }

    final keywordResult = _classifyByKeyword(
      source: source,
      normalizedName: normalizedName,
    );

    if (keywordResult != null) {
      return keywordResult;
    }

    return ShopClassification(
      shopType: 'general',
      supportsStandbyPass: _resolveStandbyPass(
        source: source,
        shopType: 'general',
      ),
      confidence: ClassificationConfidence.low,
      reason: '明確な分類条件が見つからなかったため、暫定的にグッズショップへ分類しました。手動確認してください。',
      matchedRule: 'fallback_general_shop',
    );
  }

  ShopClassification? _classifyByKeyword({
    required FacilitySource source,
    required String normalizedName,
  }) {
    if (_containsAny(normalizedName, const [
      'カプセルトイ',
      'カプセル',
      'ガチャ',
      'ガシャポン',
    ])) {
      return _createKeywordClassification(
        source: source,
        shopType: 'capsuleToy',
        matchedRule: 'keyword_capsule_toy',
        reason: '施設名にカプセルトイを示す語が含まれるため、カプセルトイに分類しました。',
      );
    }

    if (_containsAny(normalizedName, const [
      'ファッション',
      'クロージアー',
      'アパレル',
      'ブティック',
      'ウェア',
      'ハット',
    ])) {
      return _createKeywordClassification(
        source: source,
        shopType: 'apparel',
        matchedRule: 'keyword_apparel',
        reason: '施設名に衣料品販売を示す語が含まれるため、アパレルショップに分類しました。',
      );
    }

    if (_containsAny(normalizedName, const [
      'コンフェクショナリー',
      'スウィート',
      'キャンディ',
      'チョコレート',
      'ペイストリー',
      'お菓子',
    ])) {
      return _createKeywordClassification(
        source: source,
        shopType: 'confectionery',
        matchedRule: 'keyword_confectionery',
        reason: '施設名に菓子販売を示す語が含まれるため、お菓子ショップに分類しました。',
      );
    }

    if (_containsAny(normalizedName, const ['フォト', 'カメラ', '写真', 'イメージワークス'])) {
      return _createKeywordClassification(
        source: source,
        shopType: 'photoService',
        matchedRule: 'keyword_photo_service',
        reason: '施設名に写真サービスを示す語が含まれるため、フォトサービスに分類しました。',
      );
    }

    if (_containsAny(normalizedName, const [
      '期間限定',
      'ポップアップ',
      'イベントショップ',
      'スペシャルグッズ',
    ])) {
      return _createKeywordClassification(
        source: source,
        shopType: 'limited',
        matchedRule: 'keyword_limited',
        reason: '施設名に期間限定営業を示す語が含まれるため、期間限定ショップに分類しました。',
      );
    }

    if (_containsAny(normalizedName, const [
      'グリーティング',
      'ステーショナリー',
      'シルエット',
      'スタジオ',
      'トイ',
      'トレーディング',
      'ジュエリー',
      'アクセサリー',
      'マジック',
      'スポーツ',
      'キッチン',
      'ハウス',
      'コメット',
      'トレジャー',
    ])) {
      return _createKeywordClassification(
        source: source,
        shopType: 'specialty',
        matchedRule: 'keyword_specialty',
        reason: '施設名に専門商品を扱う店舗を示す語が含まれるため、専門ショップに分類しました。',
        confidence: ClassificationConfidence.medium,
      );
    }

    if (_containsAny(normalizedName, const [
      'スーベニア',
      'サンドリー',
      'メモラビリア',
      'ギフト',
      'おみやげ',
      'お土産',
    ])) {
      return _createKeywordClassification(
        source: source,
        shopType: 'souvenir',
        matchedRule: 'keyword_souvenir',
        reason: '施設名に土産品販売を示す語が含まれるため、お土産ショップに分類しました。',
        confidence: ClassificationConfidence.medium,
      );
    }

    if (_containsAny(normalizedName, const [
      'エンポーリアム',
      'マーカンタイル',
      'ストア',
      'ショップ',
      'バザール',
      'ホームストア',
    ])) {
      return _createKeywordClassification(
        source: source,
        shopType: 'general',
        matchedRule: 'keyword_general_shop',
        reason: '施設名に総合的な物販店舗を示す語が含まれるため、グッズショップに分類しました。',
      );
    }

    return null;
  }

  ShopClassification _createKeywordClassification({
    required FacilitySource source,
    required String shopType,
    required String matchedRule,
    required String reason,
    ClassificationConfidence confidence = ClassificationConfidence.high,
  }) {
    return ShopClassification(
      shopType: shopType,
      supportsStandbyPass: _resolveStandbyPass(
        source: source,
        shopType: shopType,
      ),
      confidence: confidence,
      reason: reason,
      matchedRule: matchedRule,
    );
  }

  String? _normalizeExistingType(String? shopType) {
    if (shopType == null || shopType.isEmpty || shopType == 'none') {
      return null;
    }

    if (_allowedShopTypes.contains(shopType)) {
      return shopType;
    }

    return null;
  }

  String? _findExactType(String normalizedName) {
    for (final entry in _exactTypeByName.entries) {
      if (_normalizeName(entry.key) == normalizedName) {
        return entry.value;
      }
    }

    return null;
  }

  bool _isKnownCapsuleToyName(String normalizedName) {
    for (final name in _knownCapsuleToyNames) {
      if (_normalizeName(name) == normalizedName) {
        return true;
      }
    }

    return false;
  }

  bool _resolveStandbyPass({
    required FacilitySource source,
    required String shopType,
  }) {
    return source.supportsStandbyPass;
  }

  bool _containsAny(String source, List<String> keywords) {
    for (final keyword in keywords) {
      if (source.contains(_normalizeName(keyword))) {
        return true;
      }
    }

    return false;
  }

  String _normalizeName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('　', '')
        .replaceAll('・', '')
        .replaceAll('･', '')
        .replaceAll('：', '')
        .replaceAll(':', '')
        .replaceAll('／', '')
        .replaceAll('/', '')
        .replaceAll('―', '')
        .replaceAll('—', '')
        .replaceAll('‐', '')
        .replaceAll('-', '')
        .replaceAll('“', '')
        .replaceAll('”', '')
        .replaceAll('"', '')
        .replaceAll('\'', '');
  }
}
