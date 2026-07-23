import 'classifier_models.dart';

class RestaurantClassifier {
  const RestaurantClassifier();

  static const Set<String> _allowedRestaurantTypes = {
    'tableService',
    'counterService',
    'buffet',
    'bakeryCafe',
    'snackStand',
    'foodWagon',
  };

  static const Map<String, String> _exactTypeByName = {
    'マゼランズ': 'tableService',
    'ブルーバイユー・レストラン': 'tableService',
    'れすとらん北齋': 'tableService',
    'イーストサイド・カフェ': 'tableService',
    'センターストリート・コーヒーハウス': 'tableService',
    'レストラン櫻': 'tableService',
    'リストランテ・ディ・カナレット': 'tableService',
    'S.S.コロンビア・ダイニングルーム': 'tableService',

    'クリスタルパレス・レストラン': 'buffet',
    'セイリングデイ・ブッフェ': 'buffet',

    'スウィートハート・カフェ': 'bakeryCafe',
    'マンマ・ビスコッティーズ・ベーカリー': 'bakeryCafe',

    'アイスクリームコーン': 'snackStand',
    'グレートアメリカン・ワッフルカンパニー': 'snackStand',
    'ゴンドリエ・スナック': 'snackStand',

    'スキッパーズ・ギャレー': 'foodWagon',
  };

  RestaurantClassification classify(FacilitySource source) {
    if (source.facilityType != FacilityMigrationType.restaurant) {
      return RestaurantClassification(
        restaurantType: 'none',
        supportsMobileOrder: false,
        supportsPrioritySeating: false,
        confidence: ClassificationConfidence.unknown,
        reason: 'レストラン以外の施設がRestaurantClassifierへ渡されました。',
        matchedRule: 'invalid_category',
      );
    }

    final existingType = _normalizeExistingType(source.restaurantType);

    if (existingType != null) {
      return _classificationFromExistingType(
        source: source,
        restaurantType: existingType,
      );
    }

    final normalizedName = _normalizeName(source.name);

    final exactType = _findExactType(normalizedName);

    if (exactType != null) {
      return RestaurantClassification(
        restaurantType: exactType,
        supportsMobileOrder: _resolveMobileOrder(source),
        supportsPrioritySeating: _resolvePrioritySeating(
          source: source,
          restaurantType: exactType,
        ),
        confidence: ClassificationConfidence.exact,
        reason: '施設名の完全一致ルールからレストラン種別を判定しました。',
        matchedRule: 'exact_name:$exactType',
      );
    }

    if (source.isTableService) {
      return RestaurantClassification(
        restaurantType: 'tableService',
        supportsMobileOrder: _resolveMobileOrder(source),
        supportsPrioritySeating: _resolvePrioritySeating(
          source: source,
          restaurantType: 'tableService',
        ),
        confidence: ClassificationConfidence.high,
        reason: '既存のisTableServiceがtrueのため、テーブルサービスに分類しました。',
        matchedRule: 'is_table_service',
      );
    }

    final keywordResult = _classifyByKeyword(
      source: source,
      normalizedName: normalizedName,
    );

    if (keywordResult != null) {
      return keywordResult;
    }

    return RestaurantClassification(
      restaurantType: 'counterService',
      supportsMobileOrder: _resolveMobileOrder(source),
      supportsPrioritySeating: _resolvePrioritySeating(
        source: source,
        restaurantType: 'counterService',
      ),
      confidence: ClassificationConfidence.low,
      reason: '明確な分類条件が見つからなかったため、暫定的にカウンターサービスへ分類しました。手動確認してください。',
      matchedRule: 'fallback_counter_service',
    );
  }

  RestaurantClassification _classificationFromExistingType({
    required FacilitySource source,
    required String restaurantType,
  }) {
    return RestaurantClassification(
      restaurantType: restaurantType,
      supportsMobileOrder: _resolveMobileOrder(source),
      supportsPrioritySeating: _resolvePrioritySeating(
        source: source,
        restaurantType: restaurantType,
      ),
      confidence: ClassificationConfidence.exact,
      reason: '既存のrestaurantTypeが有効なため、その値を維持しました。',
      matchedRule: 'existing_restaurant_type',
    );
  }

  RestaurantClassification? _classifyByKeyword({
    required FacilitySource source,
    required String normalizedName,
  }) {
    if (_containsAny(normalizedName, const ['ブッフェ', 'ビュッフェ', 'バイキング'])) {
      return _createKeywordClassification(
        source: source,
        restaurantType: 'buffet',
        matchedRule: 'keyword_buffet',
        reason: '施設名にブッフェ形式を示す語が含まれるため、ブッフェに分類しました。',
      );
    }

    if (_containsAny(normalizedName, const ['ワゴン', 'ポップコーン'])) {
      return _createKeywordClassification(
        source: source,
        restaurantType: 'foodWagon',
        matchedRule: 'keyword_food_wagon',
        reason: '施設名にワゴンまたはポップコーンを示す語が含まれるため、フードワゴンに分類しました。',
      );
    }

    if (_containsAny(normalizedName, const ['ベーカリー', 'ブレッド', 'パン'])) {
      return _createKeywordClassification(
        source: source,
        restaurantType: 'bakeryCafe',
        matchedRule: 'keyword_bakery_cafe',
        reason: '施設名にベーカリーを示す語が含まれるため、ベーカリー・カフェに分類しました。',
      );
    }

    if (_containsAny(normalizedName, const [
      'スナック',
      'アイスクリーム',
      'ソフトクリーム',
      'アイス',
      'チュロス',
      'ワッフル',
      'ドリンク',
      'フードブース',
    ])) {
      return _createKeywordClassification(
        source: source,
        restaurantType: 'snackStand',
        matchedRule: 'keyword_snack_stand',
        reason: '施設名に軽食販売を示す語が含まれるため、スナックスタンドに分類しました。',
      );
    }

    if (_containsAny(normalizedName, const [
      'ダイニングルーム',
      'レストラン',
      'リストランテ',
      'グリル',
    ])) {
      if (source.supportsPrioritySeating || source.isTableService) {
        return _createKeywordClassification(
          source: source,
          restaurantType: 'tableService',
          matchedRule: 'keyword_table_service_with_attribute',
          reason: '施設名と既存のテーブルサービス関連属性から、テーブルサービスに分類しました。',
        );
      }
    }

    if (_containsAny(normalizedName, const ['カフェ', 'コーヒーハウス'])) {
      if (source.isTableService || source.supportsPrioritySeating) {
        return _createKeywordClassification(
          source: source,
          restaurantType: 'tableService',
          matchedRule: 'keyword_cafe_table_service',
          reason: 'カフェ系施設名と既存の予約・テーブルサービス属性から、テーブルサービスに分類しました。',
        );
      }

      return _createKeywordClassification(
        source: source,
        restaurantType: 'bakeryCafe',
        matchedRule: 'keyword_cafe',
        reason: '施設名にカフェを示す語が含まれるため、ベーカリー・カフェに分類しました。',
        confidence: ClassificationConfidence.medium,
      );
    }

    if (_containsAny(normalizedName, const [
      'キッチン',
      'ダイナー',
      'コーナー',
      'テラス',
      'キャンティーン',
      'フードコート',
      'ピッツァ',
      'ピザ',
    ])) {
      return _createKeywordClassification(
        source: source,
        restaurantType: 'counterService',
        matchedRule: 'keyword_counter_service',
        reason: '施設名にカウンターサービス型店舗を示す語が含まれるため、カウンターサービスに分類しました。',
      );
    }

    return null;
  }

  RestaurantClassification _createKeywordClassification({
    required FacilitySource source,
    required String restaurantType,
    required String matchedRule,
    required String reason,
    ClassificationConfidence confidence = ClassificationConfidence.high,
  }) {
    return RestaurantClassification(
      restaurantType: restaurantType,
      supportsMobileOrder: _resolveMobileOrder(source),
      supportsPrioritySeating: _resolvePrioritySeating(
        source: source,
        restaurantType: restaurantType,
      ),
      confidence: confidence,
      reason: reason,
      matchedRule: matchedRule,
    );
  }

  String? _normalizeExistingType(String? restaurantType) {
    if (restaurantType == null ||
        restaurantType.isEmpty ||
        restaurantType == 'none') {
      return null;
    }

    if (_allowedRestaurantTypes.contains(restaurantType)) {
      return restaurantType;
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

  bool _resolveMobileOrder(FacilitySource source) {
    return source.supportsMobileOrder;
  }

  bool _resolvePrioritySeating({
    required FacilitySource source,
    required String restaurantType,
  }) {
    if (source.supportsPrioritySeating) {
      return true;
    }

    if (restaurantType != 'tableService') {
      return false;
    }

    return false;
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
