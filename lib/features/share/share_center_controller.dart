import 'package:flutter/foundation.dart';

import '../../app/state/app_state.dart';
import '../../data/local/share_history_store.dart';
import '../../data/services/share_file_service.dart';
import '../../domain/entities/share_import_record.dart';
import '../../domain/services/share_payload_codec.dart';

class ShareCenterController extends ChangeNotifier {
  ShareCenterController(this.appState);

  final AppState appState;
  final SharePayloadCodec codec = const SharePayloadCodec();
  final ShareFileService fileService = const ShareFileService();
  final ShareHistoryStore historyStore = const ShareHistoryStore();

  bool isBusy = false;
  String? errorMessage;
  List<ShareImportRecord> history = const [];

  String get backupJson => appState.exportBackupJson();

  String get fullShareLink => codec.encodeBackupLink(backupJson);

  String? get planShareLink {
    if (appState.daySchedule == null) {
      return null;
    }
    return codec.encodePlanLink(appState.exportSharedPlanJson());
  }

  String? get planShareCode {
    if (appState.daySchedule == null) {
      return null;
    }
    return codec.encodeRawCode(appState.exportSharedPlanJson());
  }

  Future<void> loadHistory() async {
    history = await historyStore.load();
    notifyListeners();
  }

  Future<String> importText(
    String value, {
    String sourceLabel = 'URL・共有コード',
  }) async {
    return _run(() async {
      final decoded = codec.decode(value);
      final kindLabel = await appState.importSharedData(decoded);
      await historyStore.add(
        ShareImportRecord(
          importedAt: DateTime.now(),
          sourceLabel: sourceLabel,
          kindLabel: kindLabel,
        ),
      );
      history = await historyStore.load();
      return kindLabel;
    });
  }

  Future<String?> importJsonFile() async {
    final json = await fileService.pickJson();
    if (json == null) {
      return null;
    }
    return importText(json, sourceLabel: 'JSONファイル');
  }

  Future<bool> saveBackupFile() {
    return fileService.saveJson(
      json: backupJson,
      fileName: _fileName('backup'),
    );
  }

  Future<bool> savePlanFile() {
    final json = appState.exportSharedPlanJson();
    return fileService.saveJson(json: json, fileName: _fileName('plan'));
  }

  Future<void> shareFullLink() {
    return fileService.shareText(
      text: fullShareLink,
      title: 'Disney Planner 全データ共有',
    );
  }

  Future<void> sharePlanLink() {
    final link = planShareLink;
    if (link == null) {
      throw StateError('共有できるプランがありません。');
    }
    return fileService.shareText(text: link, title: 'Disney Planner プラン共有');
  }

  Future<void> shareBackupFile() {
    return fileService.shareJsonFile(
      json: backupJson,
      fileName: _fileName('backup'),
    );
  }

  Future<void> sharePlanFile() {
    return fileService.shareJsonFile(
      json: appState.exportSharedPlanJson(),
      fileName: _fileName('plan'),
    );
  }

  Future<void> clearHistory() async {
    await historyStore.clear();
    history = const [];
    notifyListeners();
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      return await action();
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  String _fileName(String kind) {
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return 'disney_planner_${kind}_$date.json';
  }
}
