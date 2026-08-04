import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

class ShareFileService {
  const ShareFileService();

  Future<bool> saveJson({
    required String json,
    required String fileName,
  }) async {
    final output = await FilePicker.saveFile(
      dialogTitle: 'Disney Plannerデータの保存先を選択',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: Uint8List.fromList(utf8.encode(json)),
    );
    return output != null;
  }

  Future<String?> pickJson() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Disney PlannerのJSONを選択',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final bytes = result.files.single.bytes;
    if (bytes == null) {
      throw const FormatException('選択したファイルを読み込めませんでした。');
    }
    return utf8.decode(bytes);
  }

  Future<void> shareText({required String text, required String title}) async {
    await SharePlus.instance.share(
      ShareParams(text: text, title: title, subject: title),
    );
  }

  Future<void> shareJsonFile({
    required String json,
    required String fileName,
  }) async {
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(json)),
      mimeType: 'application/json',
      name: fileName,
    );

    await SharePlus.instance.share(
      ShareParams(
        text: 'Disney Plannerの共有データです。',
        title: 'Disney Planner データ共有',
        subject: 'Disney Planner データ共有',
        files: [file],
      ),
    );
  }
}
