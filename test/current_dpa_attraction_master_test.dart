import 'package:disney_planner/data/datasources/json/json_facility_data_source.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TDL attraction DPA master matches official lineup', () async {
    const dataSource = JsonFacilityDataSource();
    final facilities = await dataSource.getFacilitiesByParkId(
      'tokyo_disneyland',
    );

    final actual = facilities
        .where(
          (facility) =>
              facility.category == FacilityCategory.attraction &&
              facility.supportsDpa,
        )
        .map((facility) => facility.name)
        .toSet();

    expect(actual, {
      '美女と野獣“魔法のものがたり”',
      'ベイマックスのハッピーライド',
      'スプラッシュ・マウンテン',
      'ビッグサンダー・マウンテン',
      'プーさんのハニーハント',
      'モンスターズ・インク“ライド＆ゴーシーク！”',
      'ホーンテッドマンション',
    });
  });

  test('TDS attraction DPA master matches official lineup', () async {
    const dataSource = JsonFacilityDataSource();
    final facilities = await dataSource.getFacilitiesByParkId(
      'tokyo_disneysea',
    );

    final actual = facilities
        .where(
          (facility) =>
              facility.category == FacilityCategory.attraction &&
              facility.supportsDpa,
        )
        .map((facility) => facility.name)
        .toSet();

    expect(actual, {
      'アナとエルサのフローズンジャーニー',
      'ラプンツェルのランタンフェスティバル',
      'ピーターパンのネバーランドアドベンチャー',
      'ソアリン：ファンタスティック・フライト',
      'トイ・ストーリー・マニア！',
      'タワー・オブ・テラー',
      'センター・オブ・ジ・アース',
      'レイジングスピリッツ',
      'インディ・ジョーンズ・アドベンチャー：クリスタルスカルの魔宮',
    });
  });
}
