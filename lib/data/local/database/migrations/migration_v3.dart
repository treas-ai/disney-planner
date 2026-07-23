import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../master_data/master_data_loader.dart';

class MigrationV3 {
  const MigrationV3._();

  static Future<void> migrate(Database database) async {
    const loader = MasterDataLoader();

    await loader.importAll(database);
  }
}
