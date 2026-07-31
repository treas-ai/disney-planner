import 'package:flutter/material.dart';

import '../../../domain/entities/live_wait_time.dart';

class WaitTimeEditor extends StatefulWidget {
  const WaitTimeEditor({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.parkId,
    required this.currentWaitTime,
    required this.isSaving,
    required this.onSave,
    required this.onClear,
  });

  final String facilityId;
  final String facilityName;
  final String parkId;
  final LiveWaitTime? currentWaitTime;
  final bool isSaving;

  final Future<bool> Function(
    int waitMinutes,
  ) onSave;

  final Future<bool> Function() onClear;

  @override
  State<WaitTimeEditor> createState() {
    return _WaitTimeEditorState();
  }
}

class _WaitTimeEditorState
    extends State<WaitTimeEditor> {
  late final TextEditingController
      _waitMinutesController;

  String? _validationMessage;

  @override
  void initState() {
    super.initState();

    _waitMinutesController =
        TextEditingController(
      text: widget.currentWaitTime?.waitMinutes
          .toString(),
    );
  }

  @override
  void didUpdateWidget(
    WaitTimeEditor oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    final oldWaitMinutes =
        oldWidget.currentWaitTime?.waitMinutes;

    final newWaitMinutes =
        widget.currentWaitTime?.waitMinutes;

    if (oldWaitMinutes == newWaitMinutes) {
      return;
    }

    _waitMinutesController.text =
        newWaitMinutes?.toString() ?? '';
  }

  @override
  void dispose() {
    _waitMinutesController.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    final value = int.tryParse(
      _waitMinutesController.text.trim(),
    );

    if (value == null) {
      setState(() {
        _validationMessage =
            '待ち時間を数字で入力してください。';
      });

      return;
    }

    if (value < 0 || value > 999) {
      setState(() {
        _validationMessage =
            '0〜999分で入力してください。';
      });

      return;
    }

    setState(() {
      _validationMessage = null;
    });

    final saved = await widget.onSave(value);

    if (!mounted || !saved) {
      return;
    }

    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.facilityName}の待ち時間を$value分で保存しました。',
        ),
      ),
    );
  }

  Future<void> _clear() async {
    final cleared = await widget.onClear();

    if (!mounted || !cleared) {
      return;
    }

    _waitMinutesController.clear();

    setState(() {
      _validationMessage = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.facilityName}の待ち時間を未設定に戻しました。',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final currentWaitTime =
        widget.currentWaitTime;

    final isStale = currentWaitTime?.isStaleAt(
          DateTime.now(),
        ) ??
        false;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color:
                        colorScheme.primaryContainer,
                    borderRadius:
                        BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.schedule_outlined,
                    size: 21,
                    color: colorScheme
                        .onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.facilityName,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.w700,
                            ),
                      ),
                      Text(
                        '現在の待ち時間を入力',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (currentWaitTime != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isStale
                      ? colorScheme.errorContainer
                      : colorScheme
                          .secondaryContainer,
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      isStale
                          ? Icons
                              .warning_amber_outlined
                          : Icons
                              .check_circle_outline,
                      size: 18,
                      color: isStale
                          ? colorScheme
                              .onErrorContainer
                          : colorScheme
                              .onSecondaryContainer,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        isStale
                            ? '情報が古くなっています。'
                                '${currentWaitTime.ageLabel()}に更新'
                            : '${currentWaitTime.waitMinutes}分・'
                                '${currentWaitTime.ageLabel()}に更新',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: isStale
                                  ? colorScheme
                                      .onErrorContainer
                                  : colorScheme
                                      .onSecondaryContainer,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _waitMinutesController,
              enabled: !widget.isSaving,
              keyboardType:
                  TextInputType.number,
              textInputAction:
                  TextInputAction.done,
              onSubmitted: (_) {
                _save();
              },
              decoration: InputDecoration(
                labelText: '待ち時間',
                hintText: '例：60',
                suffixText: '分',
                prefixIcon: const Icon(
                  Icons.groups_outlined,
                ),
                errorText: _validationMessage,
                border:
                    const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (currentWaitTime != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.isSaving
                          ? null
                          : _clear,
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                      ),
                      label:
                          const Text('未設定に戻す'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.isSaving
                        ? null
                        : _save,
                    icon: widget.isSaving
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.save_outlined,
                            size: 18,
                          ),
                    label: Text(
                      widget.isSaving
                          ? '保存中'
                          : '待ち時間を保存',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '待ち時間は手動入力です。'
              'パーク内の最新案内を確認して更新してください。',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color:
                        colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}