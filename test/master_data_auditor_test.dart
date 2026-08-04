import 'package:disney_planner/data/local/master_data/data_quality/master_data_auditor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const auditor = MasterDataAuditor();

  test('show restaurant does not require standalone menu metadata', () {
    final report = auditor.audit(
      facilityRowsByFile: {
        'show_restaurant.json': [
          {
            'id': 'show_restaurant',
            'parkId': 'tokyo_disneysea',
            'areaId': 'tds_test',
            'name': 'テストショーレストラン',
            'category': 'restaurant',
            'officialUrl': 'https://www.tokyodisneyresort.jp/tds/',
            'isShowRestaurant': true,
          },
        ],
      },
    );

    expect(
      report.issues.where(
        (issue) => issue.code == 'missing_representative_menu',
      ),
      isEmpty,
    );
    expect(
      report.issues.where((issue) => issue.code == 'missing_menu_url'),
      isEmpty,
    );
  });

  test('dynamic greeting does not require fixed character references', () {
    final report = auditor.audit(
      facilityRowsByFile: {
        'greeting.json': [
          {
            'id': 'dynamic_greeting',
            'parkId': 'tokyo_disneysea',
            'areaId': 'tds_test',
            'name': '当日案内グリーティング',
            'category': 'greeting',
            'officialUrl': 'https://www.tokyodisneyresort.jp/tds/',
            'durationMinutes': 10,
            'characterIds': <String>[],
            'characterDisplayName': '当日のお楽しみ',
            'hasDynamicCharacters': true,
          },
        ],
      },
    );

    expect(
      report.issues.where(
        (issue) => issue.code == 'missing_character_reference',
      ),
      isEmpty,
    );
  });
}
