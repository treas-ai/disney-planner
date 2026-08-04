import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/manual_wait_time_entry.dart';
import '../../domain/enums/live_operation_availability.dart';
import 'manual_live_data_controller.dart';

class ManualLiveDataScreen extends StatefulWidget {
  const ManualLiveDataScreen({super.key, required this.parkId});

  final String parkId;

  @override
  State<ManualLiveDataScreen> createState() => _ManualLiveDataScreenState();
}

class _ManualLiveDataScreenState extends State<ManualLiveDataScreen> {
  late final ManualLiveDataController _controller;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller = ManualLiveDataController(parkId: widget.parkId);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _edit(Facility facility, ManualWaitTimeEntry? current) async {
    final minutesController = TextEditingController(
      text: current?.standbyMinutes?.toString() ?? '',
    );
    var availability =
        current?.availability ?? LiveOperationAvailability.operating;

    final result = await showDialog<_ManualInputResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(facility.name),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<LiveOperationAvailability>(
                      initialValue: availability,
                      decoration: const InputDecoration(
                        labelText: '運営状態',
                        border: OutlineInputBorder(),
                      ),
                      items: LiveOperationAvailability.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => availability = value);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: minutesController,
                      enabled:
                          availability == LiveOperationAvailability.operating,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '待ち時間（分）',
                        hintText: '例：45',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('公式アプリに表示されている情報を入力してください。'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    final minutes = int.tryParse(minutesController.text.trim());
                    if (availability == LiveOperationAvailability.operating &&
                        (minutes == null || minutes < 0 || minutes > 999)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('0〜999分の待ち時間を入力してください。')),
                      );
                      return;
                    }
                    Navigator.pop(
                      context,
                      _ManualInputResult(
                        availability: availability,
                        standbyMinutes: minutes,
                      ),
                    );
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    minutesController.dispose();
    if (result == null) {
      return;
    }

    await _controller.save(
      facilityId: facility.id,
      availability: result.availability,
      standbyMinutes: result.standbyMinutes,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存しました。データ取得元を手動入力へ切り替えました。')),
      );
    }
  }

  String _updatedLabel(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _differenceLabel(ManualWaitTimeEntry entry) {
    final difference = entry.differenceMinutes;
    if (difference == null || difference == 0) {
      return '';
    }
    return difference > 0 ? '（+$difference分）' : '（$difference分）';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('待ち時間を手動入力'),
        actions: [
          IconButton(
            tooltip: 'すべて削除',
            onPressed: () async {
              await _controller.clearAll();
            },
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_controller.errorMessage != null) {
            return Center(child: Text(_controller.errorMessage!));
          }

          final facilities = _controller.facilities
              .where(
                (facility) =>
                    facility.name.toLowerCase().contains(_query.toLowerCase()),
              )
              .toList(growable: false);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    const Text(
                      '公式アプリを確認し、必要な施設だけ入力してください。'
                      '30分以上経過した情報は古いデータとして警告します。',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: '施設を検索',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  itemCount: facilities.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final facility = facilities[index];
                    final entry = _controller.entries[facility.id];

                    return Card(
                      child: ListTile(
                        title: Text(facility.name),
                        subtitle: entry == null
                            ? const Text('未入力')
                            : Text(
                                '${entry.availability.label}'
                                '${entry.standbyMinutes == null ? '' : '・${entry.standbyMinutes}分${_differenceLabel(entry)}'}'
                                '・更新 ${_updatedLabel(entry.updatedAt)}'
                                '${entry.isStale ? '・30分以上経過' : ''}',
                              ),
                        leading: Icon(
                          entry?.isStale == true
                              ? Icons.warning_amber_rounded
                              : Icons.schedule_outlined,
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            if (entry != null)
                              IconButton(
                                tooltip: '削除',
                                onPressed: () =>
                                    _controller.delete(facility.id),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            IconButton(
                              tooltip: '編集',
                              onPressed: () => _edit(facility, entry),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ],
                        ),
                        onTap: () => _edit(facility, entry),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ManualInputResult {
  const _ManualInputResult({
    required this.availability,
    required this.standbyMinutes,
  });

  final LiveOperationAvailability availability;
  final int? standbyMinutes;
}
