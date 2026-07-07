import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/facility.dart';

class FacilityService {
  Future<List<Facility>> loadFacilities(String type) async {
    final path = _getAssetPath(type);
    final jsonString = await rootBundle.loadString(path);
    final List<dynamic> jsonList = jsonDecode(jsonString);

    return jsonList
        .map((json) => Facility.fromJson(json, type))
        .toList();
  }

  String _getAssetPath(String type) {
    switch (type) {
      case 'attraction':
        return 'assets/data/attractions.json';
      case 'restaurant':
        return 'assets/data/restaurants.json';
      case 'shop':
        return 'assets/data/shops.json';
      case 'show':
        return 'assets/data/shows.json';
      default:
        throw Exception('不明な施設タイプです: $type');
    }
  }
}