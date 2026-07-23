import 'classifier_models.dart';
import 'restaurant_classifier.dart';
import 'shop_classifier.dart';

class FacilityClassifier {
  const FacilityClassifier({
    this.restaurantClassifier = const RestaurantClassifier(),
    this.shopClassifier = const ShopClassifier(),
  });

  final RestaurantClassifier restaurantClassifier;
  final ShopClassifier shopClassifier;

  FacilityClassification classify(FacilitySource source) {
    return switch (source.facilityType) {
      FacilityMigrationType.restaurant => _classifyRestaurant(source),
      FacilityMigrationType.shop => _classifyShop(source),
      FacilityMigrationType.attraction => _classifyAttraction(source),
      FacilityMigrationType.show => _classifyNonTargetFacility(
        source,
        reason: 'ショーはショップ・レストラン分類の対象外です。',
      ),
      FacilityMigrationType.parade => _classifyNonTargetFacility(
        source,
        reason: 'パレードはショップ・レストラン分類の対象外です。',
      ),
      FacilityMigrationType.greeting => _classifyNonTargetFacility(
        source,
        reason: 'グリーティングはショップ・レストラン分類の対象外です。',
      ),
      FacilityMigrationType.service => _classifyNonTargetFacility(
        source,
        reason: 'サービス施設はスケジュール生成対象外のため、施設種別をnoneに統一します。',
      ),
      FacilityMigrationType.unknown => _classifyUnknownFacility(source),
    };
  }

  FacilityMigrationRecord migrate(FacilitySource source) {
    final before = Map<String, dynamic>.from(source.row);

    final classification = classify(source);

    final after = Map<String, dynamic>.from(before);

    _applyClassification(
      row: after,
      source: source,
      classification: classification,
    );

    final changedKeys = _findChangedKeys(before: before, after: after);

    return FacilityMigrationRecord(
      source: source,
      before: before,
      after: after,
      classification: classification,
      changedKeys: List<String>.unmodifiable(changedKeys),
    );
  }

  List<FacilityMigrationRecord> migrateAll({
    required String assetPath,
    required List<Map<String, dynamic>> rows,
  }) {
    final records = <FacilityMigrationRecord>[];

    for (var index = 0; index < rows.length; index++) {
      final source = FacilitySource(
        assetPath: assetPath,
        index: index,
        row: rows[index],
      );

      records.add(migrate(source));
    }

    return List<FacilityMigrationRecord>.unmodifiable(records);
  }

  FacilityClassification _classifyRestaurant(FacilitySource source) {
    final result = restaurantClassifier.classify(source);

    return FacilityClassification(
      shopType: 'none',
      restaurantType: result.restaurantType,
      supportsMobileOrder: result.supportsMobileOrder,
      supportsPrioritySeating: result.supportsPrioritySeating,
      supportsStandbyPass: source.supportsStandbyPass,
      supportsSingleRider: false,
      confidence: result.confidence,
      reason: result.reason,
      matchedRule: result.matchedRule,
    );
  }

  FacilityClassification _classifyShop(FacilitySource source) {
    final result = shopClassifier.classify(source);

    return FacilityClassification(
      shopType: result.shopType,
      restaurantType: 'none',
      supportsMobileOrder: false,
      supportsPrioritySeating: false,
      supportsStandbyPass: result.supportsStandbyPass,
      supportsSingleRider: false,
      confidence: result.confidence,
      reason: result.reason,
      matchedRule: result.matchedRule,
    );
  }

  FacilityClassification _classifyAttraction(FacilitySource source) {
    return FacilityClassification(
      shopType: 'none',
      restaurantType: 'none',
      supportsMobileOrder: false,
      supportsPrioritySeating: false,
      supportsStandbyPass: source.supportsStandbyPass,
      supportsSingleRider: source.supportsSingleRider,
      confidence: ClassificationConfidence.high,
      reason: 'アトラクションの既存サービス属性を維持し、ショップ・レストラン種別をnoneに統一しました。',
      matchedRule: 'attraction_keep_existing_services',
    );
  }

  FacilityClassification _classifyNonTargetFacility(
    FacilitySource source, {
    required String reason,
  }) {
    return FacilityClassification(
      shopType: 'none',
      restaurantType: 'none',
      supportsMobileOrder: false,
      supportsPrioritySeating: false,
      supportsStandbyPass: source.supportsStandbyPass,
      supportsSingleRider: source.supportsSingleRider,
      confidence: ClassificationConfidence.high,
      reason: reason,
      matchedRule: 'non_target_category',
    );
  }

  FacilityClassification _classifyUnknownFacility(FacilitySource source) {
    return FacilityClassification(
      shopType: source.shopType ?? 'none',
      restaurantType: source.restaurantType ?? 'none',
      supportsMobileOrder: source.supportsMobileOrder,
      supportsPrioritySeating: source.supportsPrioritySeating,
      supportsStandbyPass: source.supportsStandbyPass,
      supportsSingleRider: source.supportsSingleRider,
      confidence: ClassificationConfidence.unknown,
      reason: 'category「${source.category}」を認識できないため、自動分類できませんでした。',
      matchedRule: 'unknown_category',
    );
  }

  void _applyClassification({
    required Map<String, dynamic> row,
    required FacilitySource source,
    required FacilityClassification classification,
  }) {
    row['shopType'] = classification.shopType;

    row['restaurantType'] = classification.restaurantType;

    row['supportsMobileOrder'] = classification.supportsMobileOrder;

    row['supportsPrioritySeating'] = classification.supportsPrioritySeating;

    row['supportsStandbyPass'] = classification.supportsStandbyPass;

    row['supportsSingleRider'] = classification.supportsSingleRider;

    _normalizeCategorySpecificFields(
      row: row,
      source: source,
      classification: classification,
    );

    _ensureRequiredFacilityFields(row);
  }

  void _normalizeCategorySpecificFields({
    required Map<String, dynamic> row,
    required FacilitySource source,
    required FacilityClassification classification,
  }) {
    switch (source.facilityType) {
      case FacilityMigrationType.restaurant:
        row['isTableService'] = classification.restaurantType == 'tableService';

        row['supportsDpa'] = false;
        row['supportsPriorityPass'] = false;
        row['supportsSingleRider'] = false;

      case FacilityMigrationType.shop:
        row['isTableService'] = false;
        row['supportsMobileOrder'] = false;
        row['supportsPrioritySeating'] = false;
        row['supportsDpa'] = false;
        row['supportsPriorityPass'] = false;
        row['supportsSingleRider'] = false;

      case FacilityMigrationType.service:
        row['isTableService'] = false;
        row['supportsMobileOrder'] = false;
        row['supportsPrioritySeating'] = false;
        row['supportsDpa'] = false;
        row['supportsPriorityPass'] = false;
        row['supportsStandbyPass'] = false;
        row['supportsSingleRider'] = false;
        row['requiresEntryRequest'] = false;

      case FacilityMigrationType.show:
      case FacilityMigrationType.parade:
      case FacilityMigrationType.greeting:
        row['isTableService'] = false;
        row['supportsMobileOrder'] = false;
        row['supportsPrioritySeating'] = false;
        row['supportsSingleRider'] = false;

      case FacilityMigrationType.attraction:
      case FacilityMigrationType.unknown:
        break;
    }
  }

  void _ensureRequiredFacilityFields(Map<String, dynamic> row) {
    row.putIfAbsent('supportsDpa', () => false);

    row.putIfAbsent('supportsPriorityPass', () => false);

    row.putIfAbsent('supportsStandbyPass', () => false);

    row.putIfAbsent('supportsSingleRider', () => false);

    row.putIfAbsent('requiresEntryRequest', () => false);

    row.putIfAbsent('requiresReservation', () => false);

    row.putIfAbsent('isTableService', () => false);

    row.putIfAbsent('supportsMobileOrder', () => false);

    row.putIfAbsent('supportsPrioritySeating', () => false);

    row.putIfAbsent('reservationRequired', () => false);

    row.putIfAbsent('isIndoor', () => false);

    row.putIfAbsent('isSeasonal', () => false);

    row.putIfAbsent('isOperating', () => true);

    row.putIfAbsent('isWaterRide', () => false);

    row.putIfAbsent('isDarkRide', () => false);
  }

  List<String> _findChangedKeys({
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
  }) {
    final allKeys = <String>{...before.keys, ...after.keys};

    final changedKeys = <String>[];

    for (final key in allKeys) {
      if (!_valuesAreEqual(before[key], after[key])) {
        changedKeys.add(key);
      }
    }

    changedKeys.sort();

    return changedKeys;
  }

  bool _valuesAreEqual(dynamic first, dynamic second) {
    if (identical(first, second)) {
      return true;
    }

    if (first is num && second is num) {
      return first.toDouble() == second.toDouble();
    }

    if (first is List && second is List) {
      if (first.length != second.length) {
        return false;
      }

      for (var index = 0; index < first.length; index++) {
        if (!_valuesAreEqual(first[index], second[index])) {
          return false;
        }
      }

      return true;
    }

    if (first is Map && second is Map) {
      if (first.length != second.length) {
        return false;
      }

      for (final key in first.keys) {
        if (!second.containsKey(key)) {
          return false;
        }

        if (!_valuesAreEqual(first[key], second[key])) {
          return false;
        }
      }

      return true;
    }

    return first == second;
  }
}
