import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/visit_day_context.dart';

class LocalVisitDayContextRepository {
  const LocalVisitDayContextRepository([this._assetBundle]);

  final AssetBundle? _assetBundle;

  AssetBundle get _bundle => _assetBundle ?? rootBundle;

  Future<VisitDayRuleSet> loadRuleSet() async {
    final source = await _bundle.loadString(
      'assets/master/visit_day_context.json',
    );
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('来園日コンテキストマスターの形式が不正です。');
    }
    return VisitDayRuleSet.fromJson(decoded);
  }

  Future<VisitDayContext> loadContext(DateTime date) async {
    final rules = await loadRuleSet();
    return rules.contextFor(date);
  }
}
