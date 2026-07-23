import 'dart:convert';

import 'package:flutter/services.dart';

class MasterDataValidationException implements Exception {
  const MasterDataValidationException(this.errors);

  final List<String> errors;

  @override
  String toString() {
    return [
      'マスターデータの検証に失敗しました。',
      for (final error in errors) '- $error',
    ].join('\n');
  }
}

class MasterDataValidationResult {
  const MasterDataValidationResult({
    required this.parkRows,
    required this.areaRows,
    required this.facilityRowsByFile,
  });

  final List<Map<String, dynamic>> parkRows;

  final List<Map<String, dynamic>> areaRows;

  final Map<String, List<Map<String, dynamic>>> facilityRowsByFile;
}

class MasterDataValidator {
  const MasterDataValidator();

  static const Set<String> _allowedCategories = {
    'attraction',
    'restaurant',
    'show',
    'parade',
    'greeting',
    'shop',
    'service',
  };

  static const Set<String> _allowedRestaurantTypes = {
    'none',
    'tableService',
    'counterService',
    'buffet',
    'bakeryCafe',
    'snackStand',
    'foodWagon',
  };

  static const Set<String> _allowedShopTypes = {
    'none',
    'general',
    'capsuleToy',
    'apparel',
    'confectionery',
    'souvenir',
    'specialty',
    'limited',
    'photoService',
  };

  Future<MasterDataValidationResult> validate({
    required String manifestPath,
  }) async {
    final errors = <String>[];

    final manifest = await _loadJsonMap(manifestPath, errors);

    if (manifest == null) {
      throw MasterDataValidationException(errors);
    }

    final parkFile = _requiredPath(manifest, 'parkFile', manifestPath, errors);

    final areaFile = _requiredPath(manifest, 'areaFile', manifestPath, errors);

    final facilityFiles = _readFacilityFiles(manifest, manifestPath, errors);

    if (parkFile == null || areaFile == null) {
      throw MasterDataValidationException(errors);
    }

    final parkRows = await _loadJsonList(parkFile, errors);

    final areaRows = await _loadJsonList(areaFile, errors);

    final facilityRowsByFile = <String, List<Map<String, dynamic>>>{};

    for (final file in facilityFiles) {
      facilityRowsByFile[file] = await _loadJsonList(file, errors);
    }

    final parkIds = parkRows
        .map((row) => row['id'])
        .whereType<String>()
        .toSet();

    final areaIds = areaRows
        .map((row) => row['id'])
        .whereType<String>()
        .toSet();

    final areaParkById = <String, String>{};

    for (final row in areaRows) {
      final id = row['id'];
      final parkId = row['parkId'];

      if (id is String && parkId is String) {
        areaParkById[id] = parkId;
      }
    }

    _validateFacilities(
      facilityRowsByFile: facilityRowsByFile,
      parkIds: parkIds,
      areaIds: areaIds,
      areaParkById: areaParkById,
      errors: errors,
    );

    if (errors.isNotEmpty) {
      throw MasterDataValidationException(List<String>.unmodifiable(errors));
    }

    return MasterDataValidationResult(
      parkRows: List<Map<String, dynamic>>.unmodifiable(parkRows),
      areaRows: List<Map<String, dynamic>>.unmodifiable(areaRows),
      facilityRowsByFile: Map<String, List<Map<String, dynamic>>>.unmodifiable(
        facilityRowsByFile,
      ),
    );
  }

  void _validateFacilities({
    required Map<String, List<Map<String, dynamic>>> facilityRowsByFile,
    required Set<String> parkIds,
    required Set<String> areaIds,
    required Map<String, String> areaParkById,
    required List<String> errors,
  }) {
    final usedIds = <String>{};

    final usedOrdersByArea = <String, Set<int>>{};

    for (final entry in facilityRowsByFile.entries) {
      for (var index = 0; index < entry.value.length; index++) {
        final row = entry.value[index];

        final location = '${entry.key}[$index]';

        final id = _requiredString(row, 'id', location, errors);

        final parkId = _requiredString(row, 'parkId', location, errors);

        final areaId = _requiredString(row, 'areaId', location, errors);

        _requiredString(row, 'name', location, errors);

        final category = _requiredString(row, 'category', location, errors);

        final displayOrder = _requiredInteger(
          row,
          'displayOrder',
          location,
          errors,
        );

        if (id != null && !usedIds.add(id)) {
          errors.add(
            '$location: '
            '施設ID「$id」が重複しています。',
          );
        }

        if (parkId != null && !parkIds.contains(parkId)) {
          errors.add(
            '$location: '
            'parkId「$parkId」に対応する'
            'パークがありません。',
          );
        }

        if (areaId != null && !areaIds.contains(areaId)) {
          errors.add(
            '$location: '
            'areaId「$areaId」に対応する'
            'エリアがありません。',
          );
        }

        if (parkId != null &&
            areaId != null &&
            areaParkById[areaId] != parkId) {
          errors.add(
            '$location: '
            'parkIdとエリアの所属パークが'
            '一致しません。',
          );
        }

        if (category != null && !_allowedCategories.contains(category)) {
          errors.add(
            '$location: '
            'category「$category」は'
            '使用できません。',
          );
        }

        if (areaId != null && displayOrder != null) {
          final usedOrders = usedOrdersByArea.putIfAbsent(
            areaId,
            () => <int>{},
          );

          if (!usedOrders.add(displayOrder)) {
            errors.add(
              '$location: '
              'エリア「$areaId」内で'
              'displayOrder'
              '「$displayOrder」が'
              '重複しています。',
            );
          }
        }

        _validateTypes(
          row: row,
          category: category,
          location: location,
          errors: errors,
        );

        _validateOptionalText(
          row: row,
          key: 'representativeMenu',
          location: location,
          errors: errors,
        );

        _validateOptionalText(
          row: row,
          key: 'popcornFlavor',
          location: location,
          errors: errors,
        );

        _validateOptionalText(
          row: row,
          key: 'menuNote',
          location: location,
          errors: errors,
        );

        _validateOptionalText(
          row: row,
          key: 'showName',
          location: location,
          errors: errors,
        );

        _validateOptionalBool(
          row: row,
          key: 'isShowRestaurant',
          location: location,
          errors: errors,
        );

        final isShowRestaurant = row['isShowRestaurant'];

        if (isShowRestaurant == true && category != 'restaurant') {
          errors.add(
            '$location: '
            'ショーレストランは'
            'categoryをrestaurantに'
            'してください。',
          );
        }

        if (isShowRestaurant == true) {
          final showName = row['showName'];

          if (showName is! String || showName.trim().isEmpty) {
            errors.add(
              '$location: '
              'ショーレストランには'
              'showNameを設定してください。',
            );
          }
        }
      }
    }
  }

  void _validateTypes({
    required Map<String, dynamic> row,
    required String? category,
    required String location,
    required List<String> errors,
  }) {
    final shopType = row['shopType'] ?? 'none';

    final restaurantType = row['restaurantType'] ?? 'none';

    if (shopType is! String || !_allowedShopTypes.contains(shopType)) {
      errors.add(
        '$location: '
        'shopType「$shopType」は'
        '使用できません。',
      );
    }

    if (restaurantType is! String ||
        !_allowedRestaurantTypes.contains(restaurantType)) {
      errors.add(
        '$location: '
        'restaurantType'
        '「$restaurantType」は'
        '使用できません。',
      );
    }

    if (category == 'shop' && shopType == 'none') {
      errors.add(
        '$location: '
        'ショップにはshopTypeを'
        '設定してください。',
      );
    }

    if (category == 'restaurant' && restaurantType == 'none') {
      errors.add(
        '$location: '
        'レストランには'
        'restaurantTypeを'
        '設定してください。',
      );
    }

    if (category != 'shop' && shopType != 'none') {
      errors.add(
        '$location: '
        'ショップ以外のshopTypeは'
        'noneにしてください。',
      );
    }

    if (category != 'restaurant' && restaurantType != 'none') {
      errors.add(
        '$location: '
        'レストラン以外の'
        'restaurantTypeは'
        'noneにしてください。',
      );
    }
  }

  String? _requiredString(
    Map<String, dynamic> row,
    String key,
    String location,
    List<String> errors,
  ) {
    final value = row[key];

    if (value is String && value.trim().isNotEmpty) {
      return value;
    }

    errors.add(
      '$location: '
      '$keyは空でない文字列で'
      '指定してください。',
    );

    return null;
  }

  int? _requiredInteger(
    Map<String, dynamic> row,
    String key,
    String location,
    List<String> errors,
  ) {
    final value = row[key];

    if (value is int) {
      return value;
    }

    errors.add(
      '$location: '
      '$keyは整数で'
      '指定してください。',
    );

    return null;
  }

  void _validateOptionalText({
    required Map<String, dynamic> row,
    required String key,
    required String location,
    required List<String> errors,
  }) {
    final value = row[key];

    if (value != null && value is! String) {
      errors.add(
        '$location: '
        '$keyは文字列またはnullで'
        '指定してください。',
      );
    }
  }

  void _validateOptionalBool({
    required Map<String, dynamic> row,
    required String key,
    required String location,
    required List<String> errors,
  }) {
    final value = row[key];

    if (value != null && value is! bool) {
      errors.add(
        '$location: '
        '$keyはtrueまたはfalseで'
        '指定してください。',
      );
    }
  }

  String? _requiredPath(
    Map<String, dynamic> manifest,
    String key,
    String location,
    List<String> errors,
  ) {
    final value = manifest[key];

    if (value is String && value.trim().isNotEmpty) {
      return value;
    }

    errors.add(
      '$location: '
      '$keyが設定されていません。',
    );

    return null;
  }

  List<String> _readFacilityFiles(
    Map<String, dynamic> manifest,
    String location,
    List<String> errors,
  ) {
    final value = manifest['facilityFiles'];

    if (value is! List) {
      errors.add(
        '$location: '
        'facilityFilesは配列で'
        '指定してください。',
      );

      return <String>[];
    }

    final result = <String>[];

    for (final item in value) {
      if (item is String && item.trim().isNotEmpty) {
        result.add(item);
      }
    }

    return result;
  }

  Future<Map<String, dynamic>?> _loadJsonMap(
    String assetPath,
    List<String> errors,
  ) async {
    try {
      final source = await rootBundle.loadString(assetPath);

      final decoded = jsonDecode(source);

      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }

      errors.add(
        '$assetPath: '
        'JSONのルートはオブジェクトで'
        'ある必要があります。',
      );
    } catch (error) {
      errors.add(
        '$assetPathを読み込めませんでした: '
        '$error',
      );
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> _loadJsonList(
    String assetPath,
    List<String> errors,
  ) async {
    try {
      final source = await rootBundle.loadString(assetPath);

      final decoded = jsonDecode(source);

      if (decoded is! List) {
        errors.add(
          '$assetPath: '
          'JSONのルートは配列で'
          'ある必要があります。',
        );

        return <Map<String, dynamic>>[];
      }

      final result = <Map<String, dynamic>>[];

      for (var index = 0; index < decoded.length; index++) {
        final value = decoded[index];

        if (value is! Map) {
          errors.add(
            '$assetPath[$index]: '
            'JSONオブジェクトでは'
            'ありません。',
          );

          continue;
        }

        result.add(value.map((key, item) => MapEntry(key.toString(), item)));
      }

      return result;
    } catch (error) {
      errors.add(
        '$assetPathを読み込めませんでした: '
        '$error',
      );

      return <Map<String, dynamic>>[];
    }
  }
}
