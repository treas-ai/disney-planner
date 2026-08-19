import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/attraction_operation.dart';
import '../../domain/entities/entertainment_operation.dart';
import '../../domain/entities/live_operation_snapshot.dart';
import '../../domain/enums/live_data_source_type.dart';
import '../../domain/providers/live_data_provider.dart';
import 'themeparks_wiki_live_parser.dart';

class OfficialLiveDataProvider implements LiveDataProvider {
  const OfficialLiveDataProvider({this.client});

  final http.Client? client;

  @override
  LiveDataSourceType get sourceType => LiveDataSourceType.official;

  @override
  Future<LiveOperationSnapshot> fetchSnapshot({required String parkId}) async {
    final config = await _loadConfig(parkId);
    final entityId = config.entityId;
    if (entityId == null || entityId.isEmpty) {
      throw LiveDataProviderException('ThemeParks.wiki のパークIDが未設定です: $parkId');
    }

    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient.get(
        Uri.parse('https://api.themeparks.wiki/v1/entity/$entityId/live'),
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'DisneyPlanner/1.0 (wait-time planning client)',
        },
      );
      if (response.statusCode != 200) {
        throw LiveDataProviderException(
          'ThemeParks.wiki が HTTP ${response.statusCode} を返しました。',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const LiveDataProviderException('ライブデータ形式が不正です。');
      }

      final rows = const ThemeParksWikiLiveParser().parse(decoded);
      final attractions = <AttractionOperation>[];
      final entertainment = <EntertainmentOperation>[];
      var newest = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

      for (final row in rows) {
        if (row.updatedAt.isAfter(newest)) newest = row.updatedAt;
        final localId = config.aliases[_normalize(row.name)];
        if (localId == null) continue;
        final type = row.entityType.toUpperCase();
        if (type == 'ATTRACTION') {
          attractions.add(
            AttractionOperation(
              parkId: parkId,
              facilityId: localId,
              availability: row.availability,
              updatedAt: row.updatedAt,
              standbyMinutes: row.standbyMinutes,
              dpaAvailable: row.paidReturnAvailable,
              singleRiderAvailable:
                  row.singleRiderMinutes == null ? null : true,
              note: 'Powered by ThemeParks.wiki',
            ),
          );
        } else if (type == 'SHOW') {
          final next = row.showtimes
              .map((item) => item['startTime']?.toString())
              .whereType<String>()
              .firstOrNull;
          entertainment.add(
            EntertainmentOperation(
              parkId: parkId,
              facilityId: localId,
              availability: row.availability,
              updatedAt: row.updatedAt,
              nextPerformanceTime: next,
              note: 'Powered by ThemeParks.wiki',
            ),
          );
        }
      }

      return LiveOperationSnapshot(
        parkId: parkId,
        updatedAt: newest.millisecondsSinceEpoch == 0
            ? DateTime.now().toUtc()
            : newest,
        attractions: List.unmodifiable(attractions),
        entertainment: List.unmodifiable(entertainment),
        isMock: false,
        sourceType: LiveDataSourceType.official,
      );
    } on LiveDataProviderException {
      rethrow;
    } catch (error) {
      throw LiveDataProviderException('ThemeParks.wiki の取得に失敗しました: $error');
    } finally {
      if (client == null) httpClient.close();
    }
  }

  Future<_ThemeParksWikiConfig> _loadConfig(String parkId) async {
    final raw = await rootBundle.loadString(
      'assets/master/live_mapping/themeparks_wiki_tokyo.json',
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final park = decoded[parkId] as Map<String, dynamic>?;
    final aliases = <String, String>{};
    final rawAliases = park?['aliases'] as Map<String, dynamic>? ?? const {};
    for (final entry in rawAliases.entries) {
      aliases[_normalize(entry.key)] = entry.value.toString();
    }
    return _ThemeParksWikiConfig(
      entityId: park?['entityId']?.toString(),
      aliases: aliases,
    );
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
}

class _ThemeParksWikiConfig {
  const _ThemeParksWikiConfig({required this.entityId, required this.aliases});

  final String? entityId;
  final Map<String, String> aliases;
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
