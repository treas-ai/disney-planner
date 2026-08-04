import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  static bool get isSupported {
    if (kIsWeb) {
      return true;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _completed = false;
  String? _message;

  void _complete(String value) {
    if (_completed || value.trim().isEmpty) {
      return;
    }
    _completed = true;
    Navigator.of(context).pop(value.trim());
  }

  Future<void> _readImage() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'QRコード画像を選択',
      type: FileType.image,
    );
    final path = result?.files.single.path;
    if (path == null) {
      return;
    }

    final capture = await _controller.analyzeImage(
      path,
      formats: const [BarcodeFormat.qrCode],
    );
    if (!mounted) {
      return;
    }
    final value = capture?.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;

    if (value == null) {
      setState(() => _message = '画像からQRコードを読み取れませんでした。');
      return;
    }
    _complete(value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!QrScannerScreen.isSupported) {
      return Scaffold(
        appBar: AppBar(title: const Text('QRコード読込')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'この端末ではカメラ読込に対応していません。'
              '共有URL・共有コードの貼り付け、またはJSONファイル読込をご利用ください。',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('QRコード読込'),
        actions: [
          IconButton(
            tooltip: '画像から読み取る',
            onPressed: kIsWeb ? null : _readImage,
            icon: const Icon(Icons.image_search_outlined),
          ),
          IconButton(
            tooltip: 'ライト',
            onPressed: _controller.toggleTorch,
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                final value = barcode.rawValue;
                if (value != null) {
                  _complete(value);
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          if (_message != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(12),
                color: Colors.black87,
                child: Text(
                  _message!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
