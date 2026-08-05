import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/wish_event_pack.dart';
import '../../domain/repositories/wish_event_pack_repository.dart';

class WishEventPackRepositoryImpl implements WishEventPackRepository {
  const WishEventPackRepositoryImpl({
    this.remoteIndexUrl =
        'https://raw.githubusercontent.com/treas-ai/disney-planner/main/'
        'assets/master/events/wish_packs/index.json',
  });

  final String remoteIndexUrl;

  @override
  Future<List<WishEventPack>> loadBundledPacks() async {
    final raw = await rootBundle.loadString(
      'assets/master/events/wish_packs/index.json',
    );
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return const [];
    }

    final files = (decoded['packs'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false);

    final packs = <WishEventPack>[];
    for (final file in files) {
      final packRaw = await rootBundle.loadString(
        'assets/master/events/wish_packs/$file',
      );
      final packJson = jsonDecode(packRaw);
      if (packJson is Map) {
        packs.add(
          WishEventPack.fromJson({
            for (final entry in packJson.entries)
              entry.key.toString(): entry.value,
          }),
        );
      }
    }
    return List<WishEventPack>.unmodifiable(packs);
  }

  @override
  Future<List<WishEventPack>> refreshRemotePacks() async {
    final indexResponse = await http
        .get(Uri.parse(remoteIndexUrl))
        .timeout(const Duration(seconds: 12));
    if (indexResponse.statusCode != 200) {
      throw StateError('イベントデータ一覧を取得できませんでした。');
    }

    final decoded = jsonDecode(utf8.decode(indexResponse.bodyBytes));
    if (decoded is! Map) {
      throw const FormatException('イベントデータ一覧の形式が正しくありません。');
    }

    final files = (decoded['packs'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false);
    final baseUri = Uri.parse(remoteIndexUrl);

    final packs = <WishEventPack>[];
    for (final file in files) {
      final uri = baseUri.resolve(file);
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        continue;
      }
      final packJson = jsonDecode(utf8.decode(response.bodyBytes));
      if (packJson is Map) {
        packs.add(
          WishEventPack.fromJson({
            for (final entry in packJson.entries)
              entry.key.toString(): entry.value,
          }, isRemote: true),
        );
      }
    }

    if (packs.isEmpty) {
      throw StateError('利用できるイベントデータがありません。');
    }
    return List<WishEventPack>.unmodifiable(packs);
  }
}
