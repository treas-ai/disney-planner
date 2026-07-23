enum ClassificationConfidence {
  exact('完全一致'),
  high('高'),
  medium('中'),
  low('低'),
  unknown('未分類');

  const ClassificationConfidence(this.label);

  final String label;
}

enum FacilityMigrationType {
  attraction('アトラクション'),
  restaurant('レストラン'),
  show('ショー'),
  parade('パレード'),
  greeting('グリーティング'),
  shop('ショップ'),
  service('サービス'),
  unknown('不明');

  const FacilityMigrationType(this.label);

  final String label;

  factory FacilityMigrationType.fromCategory(String? category) {
    return switch (category) {
      'attraction' => FacilityMigrationType.attraction,
      'restaurant' => FacilityMigrationType.restaurant,
      'show' => FacilityMigrationType.show,
      'parade' => FacilityMigrationType.parade,
      'greeting' => FacilityMigrationType.greeting,
      'shop' => FacilityMigrationType.shop,
      'service' => FacilityMigrationType.service,
      _ => FacilityMigrationType.unknown,
    };
  }
}

class FacilitySource {
  const FacilitySource({
    required this.assetPath,
    required this.index,
    required this.row,
  });

  final String assetPath;
  final int index;
  final Map<String, dynamic> row;

  String get location {
    return '$assetPath[$index]';
  }

  String get id {
    final value = row['id'];

    if (value is String) {
      return value;
    }

    return '';
  }

  String get name {
    final value = row['name'];

    if (value is String) {
      return value;
    }

    return '';
  }

  String get category {
    final value = row['category'];

    if (value is String) {
      return value;
    }

    return '';
  }

  FacilityMigrationType get facilityType {
    return FacilityMigrationType.fromCategory(category);
  }

  bool get isTableService {
    return row['isTableService'] == true;
  }

  bool get supportsMobileOrder {
    return row['supportsMobileOrder'] == true;
  }

  bool get supportsPrioritySeating {
    return row['supportsPrioritySeating'] == true;
  }

  bool get supportsStandbyPass {
    return row['supportsStandbyPass'] == true;
  }

  bool get supportsSingleRider {
    return row['supportsSingleRider'] == true;
  }

  String? get shopType {
    final value = row['shopType'];

    if (value is String && value.trim().isNotEmpty) {
      return value;
    }

    return null;
  }

  String? get restaurantType {
    final value = row['restaurantType'];

    if (value is String && value.trim().isNotEmpty) {
      return value;
    }

    return null;
  }
}

class ClassificationResult {
  const ClassificationResult({
    required this.value,
    required this.confidence,
    required this.reason,
    this.matchedRule,
  });

  final String value;

  final ClassificationConfidence confidence;

  final String reason;

  final String? matchedRule;

  bool get isClassified {
    return confidence != ClassificationConfidence.unknown && value.isNotEmpty;
  }

  bool get requiresManualReview {
    return confidence == ClassificationConfidence.low ||
        confidence == ClassificationConfidence.unknown;
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'confidence': confidence.name,
      'confidenceLabel': confidence.label,
      'reason': reason,
      'matchedRule': matchedRule,
    };
  }
}

class RestaurantClassification {
  const RestaurantClassification({
    required this.restaurantType,
    required this.supportsMobileOrder,
    required this.supportsPrioritySeating,
    required this.confidence,
    required this.reason,
    this.matchedRule,
  });

  final String restaurantType;

  final bool supportsMobileOrder;

  final bool supportsPrioritySeating;

  final ClassificationConfidence confidence;

  final String reason;

  final String? matchedRule;

  bool get isClassified {
    return restaurantType.isNotEmpty && restaurantType != 'none';
  }

  bool get requiresManualReview {
    return confidence == ClassificationConfidence.low ||
        confidence == ClassificationConfidence.unknown;
  }

  Map<String, dynamic> toJson() {
    return {
      'restaurantType': restaurantType,
      'supportsMobileOrder': supportsMobileOrder,
      'supportsPrioritySeating': supportsPrioritySeating,
      'confidence': confidence.name,
      'confidenceLabel': confidence.label,
      'reason': reason,
      'matchedRule': matchedRule,
    };
  }
}

class ShopClassification {
  const ShopClassification({
    required this.shopType,
    required this.supportsStandbyPass,
    required this.confidence,
    required this.reason,
    this.matchedRule,
  });

  final String shopType;

  final bool supportsStandbyPass;

  final ClassificationConfidence confidence;

  final String reason;

  final String? matchedRule;

  bool get isClassified {
    return shopType.isNotEmpty && shopType != 'none';
  }

  bool get requiresManualReview {
    return confidence == ClassificationConfidence.low ||
        confidence == ClassificationConfidence.unknown;
  }

  Map<String, dynamic> toJson() {
    return {
      'shopType': shopType,
      'supportsStandbyPass': supportsStandbyPass,
      'confidence': confidence.name,
      'confidenceLabel': confidence.label,
      'reason': reason,
      'matchedRule': matchedRule,
    };
  }
}

class FacilityClassification {
  const FacilityClassification({
    required this.shopType,
    required this.restaurantType,
    required this.supportsMobileOrder,
    required this.supportsPrioritySeating,
    required this.supportsStandbyPass,
    required this.supportsSingleRider,
    required this.confidence,
    required this.reason,
    this.matchedRule,
  });

  factory FacilityClassification.unchanged({
    required FacilitySource source,
    String reason = 'このカテゴリは今回の自動分類対象外です。',
  }) {
    return FacilityClassification(
      shopType: source.shopType ?? 'none',
      restaurantType: source.restaurantType ?? 'none',
      supportsMobileOrder: source.supportsMobileOrder,
      supportsPrioritySeating: source.supportsPrioritySeating,
      supportsStandbyPass: source.supportsStandbyPass,
      supportsSingleRider: source.supportsSingleRider,
      confidence: ClassificationConfidence.high,
      reason: reason,
      matchedRule: 'unchanged',
    );
  }

  final String shopType;

  final String restaurantType;

  final bool supportsMobileOrder;

  final bool supportsPrioritySeating;

  final bool supportsStandbyPass;

  final bool supportsSingleRider;

  final ClassificationConfidence confidence;

  final String reason;

  final String? matchedRule;

  bool get requiresManualReview {
    return confidence == ClassificationConfidence.low ||
        confidence == ClassificationConfidence.unknown;
  }

  Map<String, dynamic> toJson() {
    return {
      'shopType': shopType,
      'restaurantType': restaurantType,
      'supportsMobileOrder': supportsMobileOrder,
      'supportsPrioritySeating': supportsPrioritySeating,
      'supportsStandbyPass': supportsStandbyPass,
      'supportsSingleRider': supportsSingleRider,
      'confidence': confidence.name,
      'confidenceLabel': confidence.label,
      'reason': reason,
      'matchedRule': matchedRule,
    };
  }
}

class FacilityMigrationRecord {
  const FacilityMigrationRecord({
    required this.source,
    required this.before,
    required this.after,
    required this.classification,
    required this.changedKeys,
  });

  final FacilitySource source;

  final Map<String, dynamic> before;

  final Map<String, dynamic> after;

  final FacilityClassification classification;

  final List<String> changedKeys;

  bool get wasChanged {
    return changedKeys.isNotEmpty;
  }

  bool get requiresManualReview {
    return classification.requiresManualReview;
  }

  Map<String, dynamic> toJson() {
    return {
      'assetPath': source.assetPath,
      'index': source.index,
      'location': source.location,
      'id': source.id,
      'name': source.name,
      'category': source.category,
      'wasChanged': wasChanged,
      'changedKeys': changedKeys,
      'classification': classification.toJson(),
      'before': before,
      'after': after,
    };
  }
}

class MigrationFileResult {
  const MigrationFileResult({
    required this.assetPath,
    required this.records,
    required this.wasWritten,
  });

  final String assetPath;

  final List<FacilityMigrationRecord> records;

  final bool wasWritten;

  int get facilityCount {
    return records.length;
  }

  int get changedFacilityCount {
    return records.where((record) => record.wasChanged).length;
  }

  int get manualReviewCount {
    return records.where((record) => record.requiresManualReview).length;
  }

  Map<String, dynamic> toJson() {
    return {
      'assetPath': assetPath,
      'facilityCount': facilityCount,
      'changedFacilityCount': changedFacilityCount,
      'manualReviewCount': manualReviewCount,
      'wasWritten': wasWritten,
      'records': records.map((record) => record.toJson()).toList(),
    };
  }
}

class MigrationSummary {
  const MigrationSummary({
    required this.startedAt,
    required this.finishedAt,
    required this.files,
    required this.dryRun,
  });

  final DateTime startedAt;

  final DateTime finishedAt;

  final List<MigrationFileResult> files;

  final bool dryRun;

  int get fileCount {
    return files.length;
  }

  int get writtenFileCount {
    return files.where((file) => file.wasWritten).length;
  }

  int get facilityCount {
    return files.fold(0, (total, file) => total + file.facilityCount);
  }

  int get changedFacilityCount {
    return files.fold(0, (total, file) => total + file.changedFacilityCount);
  }

  int get manualReviewCount {
    return files.fold(0, (total, file) => total + file.manualReviewCount);
  }

  int get restaurantCount {
    return _countByCategory('restaurant');
  }

  int get shopCount {
    return _countByCategory('shop');
  }

  int get capsuleToyCount {
    return _countMatching((record) => record.after['shopType'] == 'capsuleToy');
  }

  int get mobileOrderCount {
    return _countMatching(
      (record) => record.after['supportsMobileOrder'] == true,
    );
  }

  int get prioritySeatingCount {
    return _countMatching(
      (record) => record.after['supportsPrioritySeating'] == true,
    );
  }

  int get standbyPassCount {
    return _countMatching(
      (record) => record.after['supportsStandbyPass'] == true,
    );
  }

  Duration get elapsed {
    return finishedAt.difference(startedAt);
  }

  int _countByCategory(String category) {
    return _countMatching((record) => record.source.category == category);
  }

  int _countMatching(bool Function(FacilityMigrationRecord record) predicate) {
    var count = 0;

    for (final file in files) {
      for (final record in file.records) {
        if (predicate(record)) {
          count++;
        }
      }
    }

    return count;
  }

  Map<String, dynamic> toJson() {
    return {
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt.toIso8601String(),
      'elapsedMilliseconds': elapsed.inMilliseconds,
      'dryRun': dryRun,
      'fileCount': fileCount,
      'writtenFileCount': writtenFileCount,
      'facilityCount': facilityCount,
      'changedFacilityCount': changedFacilityCount,
      'manualReviewCount': manualReviewCount,
      'restaurantCount': restaurantCount,
      'shopCount': shopCount,
      'capsuleToyCount': capsuleToyCount,
      'mobileOrderCount': mobileOrderCount,
      'prioritySeatingCount': prioritySeatingCount,
      'standbyPassCount': standbyPassCount,
      'files': files.map((file) => file.toJson()).toList(),
    };
  }
}
