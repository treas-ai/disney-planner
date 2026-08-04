import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/entities/share_import_record.dart';
import 'qr_scanner_screen.dart';
import 'share_center_controller.dart';

class ShareCenterScreen extends StatefulWidget {
  const ShareCenterScreen({super.key});

  @override
  State<ShareCenterScreen> createState() => _ShareCenterScreenState();
}

class _ShareCenterScreenState extends State<ShareCenterScreen> {
  ShareCenterController? _controller;
  final TextEditingController _inputController = TextEditingController();

  ShareCenterController get controller => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= ShareCenterController(AppStateScope.of(context))
      ..loadHistory();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _copy(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _import(String value, {String source = '貼り付け'}) async {
    try {
      final kind = await controller.importText(value, sourceLabel: source);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$kindを読み込みました。')));
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('読み込めませんでした：$error')));
      }
    }
  }

  Future<void> _scanQr() async {
    if (!QrScannerScreen.isSupported) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('カメラ読込について'),
          content: const Text(
            'Windowsではカメラ読込を使用できません。'
            '共有URLの貼り付け、JSONファイル読込をご利用ください。',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
      return;
    }

    final value = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScannerScreen()));
    if (value != null && mounted) {
      await _import(value, source: 'QRコード');
    }
  }

  Future<void> _showQr() async {
    final link = controller.planShareLink;
    if (link == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('先にプランを作成してください。')));
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('プラン共有QRコード'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: link,
                version: QrVersions.auto,
                errorCorrectionLevel: QrErrorCorrectLevel.L,
                size: 280,
                backgroundColor: Colors.white,
                errorStateBuilder: (context, error) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'データ量が多くQRコードに収まりません。'
                      '共有URLまたはJSONファイルをご利用ください。',
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'QRコードは現在のプランだけを共有します。'
                '設定を含む全データは共有URLまたはJSONをご利用ください。',
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _copy(link, 'プラン共有URLをコピーしました。'),
            icon: const Icon(Icons.copy),
            label: const Text('URLをコピー'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPlan = AppStateScope.of(context).daySchedule != null;

    return Scaffold(
      appBar: AppBar(title: const Text('データ共有')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _InfoCard(
                icon: Icons.link,
                title: 'LINE・メールで共有',
                text:
                    'カメラは不要です。共有URLを送るか、JSONファイルを添付します。'
                    'URLはDisney Planner内へ貼り付けて読み込みます。',
              ),
              const SizedBox(height: AppSpacing.sm),
              _SectionCard(
                title: '現在のプランを共有',
                subtitle: '同行者へ送る場合におすすめ',
                children: [
                  _ActionWrap(
                    children: [
                      FilledButton.icon(
                        onPressed: hasPlan
                            ? () => _copy(
                                controller.planShareLink!,
                                'プラン共有URLをコピーしました。',
                              )
                            : null,
                        icon: const Icon(Icons.link),
                        label: const Text('URLをコピー'),
                      ),
                      OutlinedButton.icon(
                        onPressed: hasPlan ? controller.sharePlanLink : null,
                        icon: const Icon(Icons.ios_share),
                        label: const Text('LINE等へ送る'),
                      ),
                      OutlinedButton.icon(
                        onPressed: hasPlan ? _showQr : null,
                        icon: const Icon(Icons.qr_code),
                        label: const Text('QRを表示'),
                      ),
                      OutlinedButton.icon(
                        onPressed: hasPlan
                            ? () async {
                                final saved = await controller.savePlanFile();
                                if (saved && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('プランJSONを保存しました。'),
                                    ),
                                  );
                                }
                              }
                            : null,
                        icon: const Icon(Icons.save_alt),
                        label: const Text('JSON保存'),
                      ),
                      OutlinedButton.icon(
                        onPressed: hasPlan ? controller.sharePlanFile : null,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('JSONを送る'),
                      ),
                    ],
                  ),
                  if (!hasPlan)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.sm),
                      child: Text('共有するプランがありません。'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _SectionCard(
                title: 'すべてのデータを移動',
                subtitle: 'PCとスマホの引き継ぎにおすすめ',
                children: [
                  _ActionWrap(
                    children: [
                      FilledButton.icon(
                        onPressed: () => _copy(
                          controller.fullShareLink,
                          '全データ共有URLをコピーしました。',
                        ),
                        icon: const Icon(Icons.link),
                        label: const Text('URLをコピー'),
                      ),
                      OutlinedButton.icon(
                        onPressed: controller.shareFullLink,
                        icon: const Icon(Icons.ios_share),
                        label: const Text('LINE等へ送る'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final saved = await controller.saveBackupFile();
                          if (saved && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('バックアップJSONを保存しました。'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.save_alt),
                        label: const Text('JSON保存'),
                      ),
                      OutlinedButton.icon(
                        onPressed: controller.shareBackupFile,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('JSONを送る'),
                      ),
                    ],
                  ),
                  if (controller.fullShareLink.length > 8000)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.sm),
                      child: Text('全データ共有URLは長いため、LINE等ではJSONファイル共有の方が安定します。'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _SectionCard(
                title: '受け取ったデータを読み込む',
                subtitle: 'URL・共有コード・JSON・QRに対応',
                children: [
                  TextField(
                    controller: _inputController,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: '共有URL・共有コード・JSONを貼り付け',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ActionWrap(
                    children: [
                      FilledButton.icon(
                        onPressed: () => _import(_inputController.text),
                        icon: const Icon(Icons.download),
                        label: const Text('貼り付けた内容を読込'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final value = await Clipboard.getData('text/plain');
                          if (value?.text != null) {
                            _inputController.text = value!.text!;
                          }
                        },
                        icon: const Icon(Icons.content_paste),
                        label: const Text('貼り付け'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final kind = await controller.importJsonFile();
                            if (kind != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$kindを読み込みました。')),
                              );
                            }
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('読み込めませんでした：$error')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.file_open),
                        label: const Text('JSONを選択'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _scanQr,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('QRを読込'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _HistoryCard(
                history: controller.history,
                onClear: controller.history.isEmpty
                    ? null
                    : controller.clearHistory,
              ),
              if (controller.isBusy) ...[
                const SizedBox(height: AppSpacing.sm),
                const LinearProgressIndicator(),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.onPrimaryContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: TextStyle(color: colors.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ActionWrap extends StatelessWidget {
  const _ActionWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: children,
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history, required this.onClear});

  final List<ShareImportRecord> history;
  final VoidCallback? onClear;

  String _time(DateTime value) {
    return '${value.month}/${value.day} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '最近読み込んだデータ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(onPressed: onClear, child: const Text('履歴を消去')),
              ],
            ),
            if (history.isEmpty)
              const Text('履歴はありません。')
            else
              for (final item in history)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.history),
                  title: Text(item.kindLabel),
                  subtitle: Text(item.sourceLabel),
                  trailing: Text(_time(item.importedAt)),
                ),
          ],
        ),
      ),
    );
  }
}
