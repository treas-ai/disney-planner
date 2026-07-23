import 'dart:convert';

import 'facility_master_template.dart';

class FacilityJsonGenerator {
  const FacilityJsonGenerator();

  String generate(List<FacilityMasterTemplate> facilities) {
    final sortedFacilities = List<FacilityMasterTemplate>.from(facilities)
      ..sort((first, second) {
        final orderComparison = first.displayOrder.compareTo(
          second.displayOrder,
        );

        if (orderComparison != 0) {
          return orderComparison;
        }

        return first.id.compareTo(second.id);
      });

    final rows = sortedFacilities.map((facility) => facility.toJson()).toList();

    return const JsonEncoder.withIndent('  ').convert(rows);
  }

  String generateEmptyAreaFile() {
    return const JsonEncoder.withIndent(' ').convert(<Map<String, dynamic>>[]);
  }

  List<String> validateBeforeGeneration(
    List<FacilityMasterTemplate> facilities,
  ) {
    final errors = <String>[];
    final usedIds = <String>{};
    final usedDisplayOrders = <int>{};

    for (var index = 0; index < facilities.length; index++) {
      final facility = facilities[index];
      final location = 'facilities[$index]';

      if (facility.id.trim().isEmpty) {
        errors.add('$location: idが空です。');
      }

      if (!usedIds.add(facility.id)) {
        errors.add(
          '$location: id「${facility.id}」が'
          '重複しています。',
        );
      }

      if (facility.parkId.trim().isEmpty) {
        errors.add('$location: parkIdが空です。');
      }

      if (facility.areaId.trim().isEmpty) {
        errors.add('$location: areaIdが空です。');
      }

      if (facility.name.trim().isEmpty) {
        errors.add('$location: nameが空です。');
      }

      if (!_allowedCategories.contains(facility.category)) {
        errors.add(
          '$location: category'
          '「${facility.category}」は'
          '使用できません。',
        );
      }

      if (!_allowedPriorities.contains(facility.priority)) {
        errors.add(
          '$location: priority'
          '「${facility.priority}」は'
          '使用できません。',
        );
      }

      if (!_allowedStatuses.contains(facility.status)) {
        errors.add(
          '$location: status'
          '「${facility.status}」は'
          '使用できません。',
        );
      }

      if (facility.displayOrder < 1) {
        errors.add(
          '$location: displayOrderは'
          '1以上で指定してください。',
        );
      }

      if (!usedDisplayOrders.add(facility.displayOrder)) {
        errors.add(
          '$location: displayOrder'
          '「${facility.displayOrder}」が'
          '同じファイル内で重複しています。',
        );
      }

      if (facility.durationMinutes < 1) {
        errors.add(
          '$location: durationMinutesは'
          '1以上で指定してください。',
        );
      }

      if (facility.minHeight != null && facility.minHeight! < 0) {
        errors.add(
          '$location: minHeightに'
          '負の値は指定できません。',
        );
      }

      if (facility.thrillLevel != null &&
          (facility.thrillLevel! < 0 || facility.thrillLevel! > 5)) {
        errors.add(
          '$location: thrillLevelは'
          '0から5で指定してください。',
        );
      }
    }

    return List.unmodifiable(errors);
  }

  String generateOrThrow(List<FacilityMasterTemplate> facilities) {
    final errors = validateBeforeGeneration(facilities);

    if (errors.isNotEmpty) {
      throw FacilityJsonGenerationException(errors);
    }

    return generate(facilities);
  }

  static const Set<String> _allowedCategories = {
    'attraction',
    'restaurant',
    'show',
    'parade',
    'greeting',
    'service',
    'shop',
  };

  static const Set<String> _allowedPriorities = {
    'lowest',
    'low',
    'medium',
    'high',
    'highest',
  };

  static const Set<String> _allowedStatuses = {
    'open',
    'closed',
    'temporarilyClosed',
  };
}

class FacilityJsonGenerationException implements Exception {
  const FacilityJsonGenerationException(this.errors);

  final List<String> errors;

  @override
  String toString() {
    return [
      '施設JSONの生成前検証に失敗しました。',
      for (final error in errors) '- $error',
    ].join('\n');
  }
}
