import 'package:flutter_test/flutter_test.dart';

import 'package:disney_planner/data/local/master_data/master_data_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('runtime master assets pass full manifest validation', () async {
    const validator = MasterDataValidator();

    final result = await validator.validate(
      manifestPath: MasterDataLoaderManifest.path,
    );

    expect(result.parkRows, isNotEmpty);
    expect(result.areaRows, isNotEmpty);
    expect(result.facilityRowsByFile, isNotEmpty);
  });
}

abstract final class MasterDataLoaderManifest {
  static const String path = 'assets/master/master_manifest.json';
}
