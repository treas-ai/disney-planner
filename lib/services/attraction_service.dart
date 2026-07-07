import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/attraction.dart';

class AttractionService {
  Future<List<Attraction>> loadAttractions() async {
    final jsonString =
        await rootBundle.loadString('assets/data/attractions.json');

    final List<dynamic> jsonList = jsonDecode(jsonString);

    return jsonList
        .map((json) => Attraction.fromJson(json))
        .toList();
  }
}