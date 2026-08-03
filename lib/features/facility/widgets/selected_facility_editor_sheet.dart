import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_status_chip.dart';
import '../../../domain/entities/facility.dart';
import '../../../domain/enums/facility_category.dart';
import '../../live/live_wait_time_controller.dart';
import '../../live/widgets/wait_time_editor.dart';
import '../plan_builder_controller.dart';
import '../plan_preference_controller.dart';
import 'plan_preference_editor.dart';

class SelectedFacilityEditorSheet extends StatefulWidget {
  const SelectedFacilityEditorSheet({
    super.key,
    required this.planBuilderController,
    required this.preferenceController,
    required this.selectedParkId,
    required this.onReviewPlanPressed,
  });

  final PlanBuilderController planBuilderController;
  final PlanPreferenceController preferenceController;
  final String selectedParkId;
  final VoidCallback onReviewPlanPressed;

  @override
  State<SelectedFacilityEditorSheet> createState() {
    return _SelectedFacilityEditorSheetState();
  }
}

class _SelectedFacilityEditorSheetState
    extends State<SelectedFacilityEditorSheet> {
  late String _displayedParkId;
  late final LiveWaitTimeController _liveWaitTimeController;

  @override
  void initState() {
    super.initState();

    _displayedParkId = widget.selectedParkId;

    _liveWaitTimeController = LiveWaitTimeController();

    widget.planBuilderController.addListener(_refresh);
    widget.preferenceController.addListener(_refresh);
    _liveWaitTimeController.addListener(_refresh);

    _loadWaitTimes();
  }

  @override
  void dispose() {
    widget.planBuilderController.removeListener(_refresh);
    widget.preferenceController.removeListener(_refresh);
    _liveWaitTimeController.removeListener(_refresh);

    _liveWaitTimeController.dispose();

    super.dispose();
  }

  Future<void> _loadWaitTimes() async {
    await _liveWaitTimeController.loadForPark(_displayedParkId);
  }

  void _refresh() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _changeDisplayedPark(String parkId) async {
    if (parkId == _displayedParkId) {
      return;
    }

    setState(() {
      _displayedParkId = parkId;
    });

    await _liveWaitTimeController.loadForPark(parkId);
  }

  void _goToPlanReview() {
    Navigator.of(context).pop();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onReviewPlanPressed();
    });
  }

  Future<void> _confirmRemove(Facility facility) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('選択を解除しますか？'),
          content: Text(
            '「${facility.name}」をプランから削除します。\n\n'
            'この施設に設定した希望条件も削除されます。\n'
            '当日待ち時間の入力値は削除されません。',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('キャンセル'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (shouldRemove != true) {
      return;
    }

    widget.planBuilderController.removeFacility(facility.id);
  }

  void _reorderFacility(int oldIndex, int adjustedNewIndex) {
    final legacyNewIndex = adjustedNewIndex > oldIndex
        ? adjustedNewIndex + 1
        : adjustedNewIndex;

    widget.planBuilderController.reorderFacilitiesForPark(
      parkId: _displayedParkId,
      oldIndex: oldIndex,
      newIndex: legacyNewIndex,
    );
  }

  Future<bool> _saveWaitTime({
    required Facility facility,
    required int waitMinutes,
  }) {
    return _liveWaitTimeController.updateWaitTime(
      facilityId: facility.id,
      parkId: facility.parkId,
      waitMinutes: waitMinutes,
    );
  }

  Future<bool> _clearWaitTime(Facility facility) {
    return _liveWaitTimeController.removeWaitTime(facility.id);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.planBuilderController;

    final facilities = controller.selectedFacilitiesForPark(_displayedParkId);

    final landCount = controller.selectedFacilityCountForPark(
      'tokyo_disneyland',
    );

    final seaCount = controller.selectedFacilityCountForPark('tokyo_disneysea');

    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.90,
      minChildSize: 0.55,
      maxChildSize: 0.97,
      builder: (context, scrollController) {
        return Material(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _SheetHeader(
                displayedParkId: _displayedParkId,
                facilityCount: facilities.length,
                isSaving:
                    controller.isSaving || _liveWaitTimeController.isSaving,
                onClose: () {
                  Navigator.of(context).pop();
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: _ParkSelectionRow(
                  selectedParkId: _displayedParkId,
                  landCount: landCount,
                  seaCount: seaCount,
                  onChanged: _changeDisplayedPark,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _ReorderInformation(enabled: facilities.length >= 2),
              ),
              if (_liveWaitTimeController.errorMessage != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _WaitTimeErrorCard(
                    message: _liveWaitTimeController.errorMessage!,
                    onClose: _liveWaitTimeController.clearError,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: _liveWaitTimeController.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : facilities.isEmpty
                    ? _EmptySelectedFacilities(parkId: _displayedParkId)
                    : ReorderableListView.builder(
                        scrollController: scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        buildDefaultDragHandles: false,
                        itemCount: facilities.length,
                        onReorderItem: _reorderFacility,
                        itemBuilder: (context, index) {
                          final facility = facilities[index];

                          return _SelectedFacilityItem(
                            key: ValueKey(facility.id),
                            index: index,
                            facility: facility,
                            preferenceController: widget.preferenceController,
                            liveWaitTimeController: _liveWaitTimeController,
                            onSaveWaitTime: (waitMinutes) {
                              return _saveWaitTime(
                                facility: facility,
                                waitMinutes: waitMinutes,
                              );
                            },
                            onClearWaitTime: () {
                              return _clearWaitTime(facility);
                            },
                            onRemove: () {
                              _confirmRemove(facility);
                            },
                          );
                        },
                      ),
              ),
              _ReviewActionFooter(
                selectedCount: facilities.length,
                onPressed: _goToPlanReview,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReviewActionFooter extends StatelessWidget {
  const _ReviewActionFooter({
    required this.selectedCount,
    required this.onPressed,
  });

  final int selectedCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedCount == 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '施設を1件以上選択してください。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: selectedCount > 0 ? onPressed : null,
                icon: const Icon(Icons.arrow_forward, size: 19),
                label: Text(
                  selectedCount > 0 ? '$selectedCount件の施設でプラン確認へ' : 'プラン確認へ',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.displayedParkId,
    required this.facilityCount,
    required this.isSaving,
    required this.onClose,
  });

  final String displayedParkId;
  final int facilityCount;
  final bool isSaving;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
      child: Row(
        children: [
          Icon(_parkIcon(displayedParkId), size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '選択施設',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${_parkName(displayedParkId)}・$facilityCount件',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          AppStatusChip(
            label: isSaving ? '保存中' : '保存済み',
            type: isSaving ? AppStatusType.info : AppStatusType.success,
            icon: isSaving ? Icons.sync : Icons.cloud_done_outlined,
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: '閉じる',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _ParkSelectionRow extends StatelessWidget {
  const _ParkSelectionRow({
    required this.selectedParkId,
    required this.landCount,
    required this.seaCount,
    required this.onChanged,
  });

  final String selectedParkId;
  final int landCount;
  final int seaCount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ParkCountButton(
            label: 'ランド',
            icon: Icons.castle_outlined,
            count: landCount,
            selected: selectedParkId == 'tokyo_disneyland',
            onPressed: () {
              onChanged('tokyo_disneyland');
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ParkCountButton(
            label: 'シー',
            icon: Icons.water_outlined,
            count: seaCount,
            selected: selectedParkId == 'tokyo_disneysea',
            onPressed: () {
              onChanged('tokyo_disneysea');
            },
          ),
        ),
      ],
    );
  }
}

class _ParkCountButton extends StatelessWidget {
  const _ParkCountButton({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: selected ? null : onPressed,
        child: SizedBox(
          height: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              AppBadge(label: '$count', compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReorderInformation extends StatelessWidget {
  const _ReorderInformation({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Icon(
            Icons.drag_indicator,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              enabled ? '右端のハンドルをドラッグして施設の順番を変更できます。' : '2件以上選択すると並び替えできます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitTimeErrorCard extends StatelessWidget {
  const _WaitTimeErrorCard({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: '閉じる',
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.close,
              size: 17,
              color: colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySelectedFacilities extends StatelessWidget {
  const _EmptySelectedFacilities({required this.parkId});

  final String parkId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.playlist_add_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '選択済み施設はありません',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${_parkName(parkId)}の施設一覧から追加してください。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedFacilityItem extends StatelessWidget {
  const _SelectedFacilityItem({
    super.key,
    required this.index,
    required this.facility,
    required this.preferenceController,
    required this.liveWaitTimeController,
    required this.onSaveWaitTime,
    required this.onClearWaitTime,
    required this.onRemove,
  });

  final int index;
  final Facility facility;
  final PlanPreferenceController preferenceController;
  final LiveWaitTimeController liveWaitTimeController;

  final Future<bool> Function(int waitMinutes) onSaveWaitTime;

  final Future<bool> Function() onClearWaitTime;

  final VoidCallback onRemove;

  bool get _supportsLiveWaitTime {
    return facility.category == FacilityCategory.attraction;
  }

  @override
  Widget build(BuildContext context) {
    final preference = preferenceController.getPreference(facility.id);

    if (preference == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    final liveWaitTime = liveWaitTimeController.waitTimeForFacility(
      facility.id,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(10, 3, 4, 3),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        leading: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            '${index + 1}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          facility.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              AppBadge(
                label: _categoryLabel(facility),
                icon: _categoryIcon(facility),
              ),
              if (_supportsLiveWaitTime && liveWaitTime != null)
                _LiveWaitTimeBadge(
                  waitMinutes: liveWaitTime.waitMinutes,
                  isStale: liveWaitTime.isStaleAt(DateTime.now()),
                ),
              if (!facility.isOpen)
                AppStatusChip(
                  label: facility.operatingStatusDisplayLabel,
                  type: AppStatusType.warning,
                ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '選択解除',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, size: 20),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Tooltip(
                message: '並び替え',
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.drag_handle,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          PlanPreferenceEditor(
            facility: facility,
            preference: preference,
            onPriorityChanged: (priority) {
              preferenceController.updatePriority(
                facilityId: facility.id,
                priority: priority,
              );
            },
            onPreferredTimeChanged: (preferredTime) {
              preferenceController.updatePreferredTime(
                facilityId: facility.id,
                preferredTime: preferredTime,
              );
            },
            onWaitToleranceChanged: (waitTolerance) {
              preferenceController.updateWaitTolerance(
                facilityId: facility.id,
                waitTolerance: waitTolerance,
              );
            },
            onMealPreferenceChanged: (mealPreference) {
              preferenceController.updateMealPreference(
                facilityId: facility.id,
                mealPreference: mealPreference,
              );
            },
            onAccessMethodChanged: (accessMethod) {
              preferenceController.updateAccessMethod(
                facilityId: facility.id,
                accessMethod: accessMethod,
              );
            },
            onPreferredPerformanceTimeChanged: (value) {
              preferenceController.updatePreferredPerformanceTime(
                facilityId: facility.id,
                value: value,
              );
            },
            onReservationTimeChanged: (value) {
              preferenceController.updateReservationTime(
                facilityId: facility.id,
                value: value,
              );
            },
            onScheduledAccessTimeChanged: (value) {
              preferenceController.updateScheduledAccessTime(
                facilityId: facility.id,
                value: value,
              );
            },
            onLotteryFallbackActionChanged: (action) {
              preferenceController.updateLotteryFallbackAction(
                facilityId: facility.id,
                action: action,
              );
            },
            onUseDpaChanged: (value) {
              preferenceController.updateUseDpa(
                facilityId: facility.id,
                value: value,
              );
            },
            onUsePriorityPassChanged: (value) {
              preferenceController.updateUsePriorityPass(
                facilityId: facility.id,
                value: value,
              );
            },
            onUseStandbyPassChanged: (value) {
              preferenceController.updateUseStandbyPass(
                facilityId: facility.id,
                value: value,
              );
            },
            onPrioritizeCapsuleToyChanged: (value) {
              preferenceController.updatePrioritizeCapsuleToy(
                facilityId: facility.id,
                value: value,
              );
            },
            onMemoChanged: (memo) {
              preferenceController.updateMemo(
                facilityId: facility.id,
                memo: memo,
              );
            },
          ),
          if (_supportsLiveWaitTime) ...[
            const SizedBox(height: AppSpacing.md),
            WaitTimeEditor(
              facilityId: facility.id,
              facilityName: facility.name,
              parkId: facility.parkId,
              currentWaitTime: liveWaitTime,
              isSaving: liveWaitTimeController.isSaving,
              onSave: onSaveWaitTime,
              onClear: onClearWaitTime,
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveWaitTimeBadge extends StatelessWidget {
  const _LiveWaitTimeBadge({required this.waitMinutes, required this.isStale});

  final int waitMinutes;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 25),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isStale
            ? colorScheme.errorContainer
            : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isStale ? colorScheme.error : colorScheme.secondary,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isStale ? Icons.warning_amber_outlined : Icons.groups_outlined,
            size: 14,
            color: isStale
                ? colorScheme.onErrorContainer
                : colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            isStale ? '待ち時間 $waitMinutes分・要更新' : '待ち時間 $waitMinutes分',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isStale
                  ? colorScheme.onErrorContainer
                  : colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _parkName(String parkId) {
  return switch (parkId) {
    'tokyo_disneyland' => '東京ディズニーランド',
    'tokyo_disneysea' => '東京ディズニーシー',
    _ => parkId,
  };
}

IconData _parkIcon(String parkId) {
  return switch (parkId) {
    'tokyo_disneyland' => Icons.castle_outlined,
    'tokyo_disneysea' => Icons.water_outlined,
    _ => Icons.park_outlined,
  };
}

String _categoryLabel(Facility facility) {
  if (facility.isShop) {
    return facility.shopType.label;
  }

  if (facility.isRestaurant) {
    return facility.restaurantType.label;
  }

  return switch (facility.category.name) {
    'attraction' => 'アトラクション',
    'restaurant' => 'レストラン',
    'show' => 'ショー・パレード',
    'parade' => 'ショー・パレード',
    'greeting' => 'グリーティング',
    'shop' => 'ショップ',
    'service' => 'サービス',
    _ => facility.category.label,
  };
}

IconData _categoryIcon(Facility facility) {
  return switch (facility.category.name) {
    'attraction' => Icons.attractions_outlined,
    'restaurant' => Icons.restaurant_outlined,
    'show' => Icons.theater_comedy_outlined,
    'parade' => Icons.theater_comedy_outlined,
    'greeting' => Icons.photo_camera_front_outlined,
    'shop' => Icons.storefront_outlined,
    'service' => Icons.info_outline,
    _ => Icons.place_outlined,
  };
}
