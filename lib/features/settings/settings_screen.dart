import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/state/app_state_scope.dart';
import '../../core/constants/app_version.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/local/data_freshness_service.dart';
import '../../domain/entities/data_freshness_info.dart';
import '../../domain/entities/trip_settings.dart';
import '../../domain/services/entry_prediction_service.dart';
import '../../domain/enums/live_data_source_type.dart';
import '../share/share_center_screen.dart';
import 'settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() {
    return _SettingsScreenState();
  }
}

class _SettingsScreenState extends State<SettingsScreen> {
  SettingsController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_controller != null) {
      return;
    }

    final appState = AppStateScope.of(context);

    _controller = SettingsController(appState);
    _controller!.addListener(_refresh);
  }

  @override
  void dispose() {
    _controller?.removeListener(_refresh);
    _controller?.dispose();

    super.dispose();
  }

  void _refresh() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _selectQueueArrivalTime() async {
    final controller = _controller;

    if (controller == null) {
      return;
    }

    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: controller.settings.queueArrivalTimeHour,
        minute: controller.settings.queueArrivalTimeMinute,
      ),
      helpText: '並び開始時刻を選択',
      cancelText: 'キャンセル',
      confirmText: '決定',
    );

    if (selected != null) {
      controller.updateQueueArrivalTime(selected);
    }
  }

  Future<void> _selectHappyEntryTime() async {
    final controller = _controller;
    if (controller == null) return;

    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: controller.settings.happyEntryTimeHour,
        minute: controller.settings.happyEntryTimeMinute,
      ),
      helpText: '通行証記載の先行入園時刻を選択',
      cancelText: 'キャンセル',
      confirmText: '決定',
    );

    if (selected != null) {
      controller.updateHappyEntryTime(selected);
    }
  }

  Future<void> _selectEntryTime() async {
    final controller = _controller;

    if (controller == null) {
      return;
    }

    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: controller.settings.entryTimeHour,
        minute: controller.settings.entryTimeMinute,
      ),
      helpText: '公式開園予定時刻を選択',
      cancelText: 'キャンセル',
      confirmText: '決定',
    );

    if (selected != null) {
      controller.updateEntryTime(selected);
    }
  }

  Future<void> _selectExitTime() async {
    final controller = _controller;

    if (controller == null) {
      return;
    }

    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: controller.settings.exitTimeHour,
        minute: controller.settings.exitTimeMinute,
      ),
      helpText: '退園時刻を選択',
      cancelText: 'キャンセル',
      confirmText: '決定',
    );

    if (selected != null) {
      controller.updateExitTime(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller == null) {
      return const AppScaffold(child: LoadingView(message: '設定画面を準備中です...'));
    }

    final settings = controller.settings;

    return AppScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useTwoColumns = constraints.maxWidth >= 760;

          if (useTwoColumns) {
            return _DesktopSettingsLayout(
              settings: settings,
              controller: controller,
              onQueueArrivalTimePressed: _selectQueueArrivalTime,
              onHappyEntryTimePressed: _selectHappyEntryTime,
              onEntryTimePressed: _selectEntryTime,
              onExitTimePressed: _selectExitTime,
            );
          }

          return _MobileSettingsLayout(
            settings: settings,
            controller: controller,
            onQueueArrivalTimePressed: _selectQueueArrivalTime,
            onHappyEntryTimePressed: _selectHappyEntryTime,
            onEntryTimePressed: _selectEntryTime,
            onExitTimePressed: _selectExitTime,
          );
        },
      ),
    );
  }
}

class _MobileSettingsLayout extends StatelessWidget {
  const _MobileSettingsLayout({
    required this.settings,
    required this.controller,
    required this.onQueueArrivalTimePressed,
    required this.onHappyEntryTimePressed,
    required this.onEntryTimePressed,
    required this.onExitTimePressed,
  });

  final TripSettings settings;
  final SettingsController controller;
  final VoidCallback onQueueArrivalTimePressed;
  final VoidCallback onHappyEntryTimePressed;
  final VoidCallback onEntryTimePressed;
  final VoidCallback onExitTimePressed;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      interactive: true,
      child: ListView(
        padding: const EdgeInsets.only(right: 12, bottom: 96),
        children: [
          const _SettingsIntroCard(),
          const SizedBox(height: AppSpacing.sm),
          _VisitDaysCard(controller: controller),
          const SizedBox(height: AppSpacing.sm),
          _ParkSettingsCard(
            settings: settings,
            onChanged: controller.updatePark,
          ),
          const SizedBox(height: AppSpacing.sm),
          _VisitSummaryCard(
            settings: settings,
            onQueueArrivalTimePressed: onQueueArrivalTimePressed,
            onHappyEntryTimePressed: onHappyEntryTimePressed,
            onEntryTimePressed: onEntryTimePressed,
            onExitTimePressed: onExitTimePressed,
            onDecreasePeople: controller.decreasePeople,
            onIncreasePeople: controller.increasePeople,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ServiceSettingsCard(
            settings: settings,
            onHappyEntryChanged: controller.updateHappyEntry,
            onAttractionDpaMaxUsesChanged: controller.updateAttractionDpaMaxUses,
            onSingleRiderChanged: controller.updateSingleRider,
            onVacationPackageChanged: controller.updateVacationPackage,
            onFreeDrinkChanged: controller.updateFreeDrinkBenefit,
            onAttractionVoucherChanged: controller.updateAttractionVoucher,
            onShowVoucherChanged: controller.updateShowVoucher,
            onRestaurantReservationChanged:
                controller.updateRestaurantReservation,
          ),
          const SizedBox(height: AppSpacing.sm),
          _MealSettingsCard(
            settings: settings,
            onBreakfastChanged: controller.updateBreakfast,
            onLunchChanged: controller.updateLunch,
            onDinnerChanged: controller.updateDinner,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ExpandableSettingsSection(
            title: '詳細設定',
            subtitle: '必要な場合だけ変更してください',
            icon: Icons.tune_outlined,
            children: [
              _ConditionSettingsCard(
                settings: settings,
                onRainyChanged: controller.updateRainy,
                onChildrenChanged: controller.updateChildren,
              ),
              const SizedBox(height: AppSpacing.sm),
              _LiveDataSourceSettingsCard(
                value: controller.liveDataSource,
                isLoading: controller.isLoadingLiveDataSource,
                onChanged: controller.updateLiveDataSource,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _ExpandableSettingsSection(
            title: 'データ管理・その他',
            subtitle: 'バックアップ、共有、更新情報',
            icon: Icons.folder_copy_outlined,
            children: [
              const _DataFreshnessCard(),
              const SizedBox(height: AppSpacing.sm),
              _BackupRestoreCard(controller: controller),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesktopSettingsLayout extends StatelessWidget {
  const _DesktopSettingsLayout({
    required this.settings,
    required this.controller,
    required this.onQueueArrivalTimePressed,
    required this.onHappyEntryTimePressed,
    required this.onEntryTimePressed,
    required this.onExitTimePressed,
  });

  final TripSettings settings;
  final SettingsController controller;
  final VoidCallback onQueueArrivalTimePressed;
  final VoidCallback onHappyEntryTimePressed;
  final VoidCallback onEntryTimePressed;
  final VoidCallback onExitTimePressed;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      interactive: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(right: 14, bottom: 48),
        child: Column(
          children: [
            const _SettingsIntroCard(),
            const SizedBox(height: AppSpacing.sm),
            _VisitDaysCard(controller: controller),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _ParkSettingsCard(
                        settings: settings,
                        onChanged: controller.updatePark,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _VisitSummaryCard(
                        settings: settings,
                        onQueueArrivalTimePressed: onQueueArrivalTimePressed,
                        onHappyEntryTimePressed: onHappyEntryTimePressed,
                        onEntryTimePressed: onEntryTimePressed,
                        onExitTimePressed: onExitTimePressed,
                        onDecreasePeople: controller.decreasePeople,
                        onIncreasePeople: controller.increasePeople,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _MealSettingsCard(
                        settings: settings,
                        onBreakfastChanged: controller.updateBreakfast,
                        onLunchChanged: controller.updateLunch,
                        onDinnerChanged: controller.updateDinner,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    children: [
                      _ServiceSettingsCard(
                        settings: settings,
                        onHappyEntryChanged: controller.updateHappyEntry,
                        onAttractionDpaMaxUsesChanged: controller.updateAttractionDpaMaxUses,
                        onSingleRiderChanged: controller.updateSingleRider,
                        onVacationPackageChanged:
                            controller.updateVacationPackage,
                        onFreeDrinkChanged:
                            controller.updateFreeDrinkBenefit,
                        onAttractionVoucherChanged:
                            controller.updateAttractionVoucher,
                        onShowVoucherChanged: controller.updateShowVoucher,
                        onRestaurantReservationChanged:
                            controller.updateRestaurantReservation,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ExpandableSettingsSection(
                        title: '詳細設定',
                        subtitle: '必要な場合だけ変更してください',
                        icon: Icons.tune_outlined,
                        children: [
                          _ConditionSettingsCard(
                            settings: settings,
                            onRainyChanged: controller.updateRainy,
                            onChildrenChanged: controller.updateChildren,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _LiveDataSourceSettingsCard(
                            value: controller.liveDataSource,
                            isLoading: controller.isLoadingLiveDataSource,
                            onChanged: controller.updateLiveDataSource,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ExpandableSettingsSection(
                        title: 'データ管理・その他',
                        subtitle: 'バックアップ、共有、更新情報',
                        icon: Icons.folder_copy_outlined,
                        children: [
                          const _DataFreshnessCard(),
                          const SizedBox(height: AppSpacing.sm),
                          _BackupRestoreCard(controller: controller),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


Future<DateTime?> _showJapaneseDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required String title,
  required String confirmText,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) => _JapaneseDatePickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      title: title,
      confirmText: confirmText,
    ),
  );
}

class _JapaneseDatePickerDialog extends StatefulWidget {
  const _JapaneseDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.confirmText,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final String confirmText;

  @override
  State<_JapaneseDatePickerDialog> createState() =>
      _JapaneseDatePickerDialogState();
}

class _JapaneseDatePickerDialogState
    extends State<_JapaneseDatePickerDialog> {
  static const _weekdays = ['日', '月', '火', '水', '木', '金', '土'];

  late DateTime _selectedDate;
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  bool get _canGoPrevious {
    final previous = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
    return !previous.isBefore(DateTime(widget.firstDate.year, widget.firstDate.month));
  }

  bool get _canGoNext {
    final next = DateTime(_displayedMonth.year, _displayedMonth.month + 1);
    return !next.isAfter(DateTime(widget.lastDate.year, widget.lastDate.month));
  }

  void _changeMonth(int offset) {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + offset,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final firstOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month);
    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    final leadingEmptyCells = firstOfMonth.weekday % 7;
    final totalCells = ((leadingEmptyCells + daysInMonth + 6) ~/ 7) * 7;

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.62,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            Row(
              children: [
                IconButton(
                  onPressed: _canGoPrevious ? () => _changeMonth(-1) : null,
                  tooltip: '前の月',
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${_displayedMonth.year}年${_displayedMonth.month}月',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _canGoNext ? () => _changeMonth(1) : null,
                  tooltip: '次の月',
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 7,
              childAspectRatio: 1.45,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final weekday in _weekdays)
                  Center(
                    child: Text(
                      weekday,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                for (var index = 0; index < totalCells; index++)
                  if (index < leadingEmptyCells ||
                      index >= leadingEmptyCells + daysInMonth)
                    const SizedBox.shrink()
                  else
                    Builder(
                      builder: (context) {
                        final day = index - leadingEmptyCells + 1;
                        final date = DateTime(
                          _displayedMonth.year,
                          _displayedMonth.month,
                          day,
                        );
                        final isSelected =
                            date.year == _selectedDate.year &&
                            date.month == _selectedDate.month &&
                            date.day == _selectedDate.day;
                        final isEnabled = !date.isBefore(widget.firstDate) &&
                            !date.isAfter(widget.lastDate);

                        return Padding(
                          padding: const EdgeInsets.all(2),
                          child: InkWell(
                            onTap: isEnabled
                                ? () => setState(() => _selectedDate = date)
                                : null,
                            borderRadius: BorderRadius.circular(24),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? colorScheme.primary
                                    : Colors.transparent,
                              ),
                              child: Center(
                                child: Text(
                                  '$day',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isSelected
                                        ? colorScheme.onPrimary
                                        : isEnabled
                                            ? colorScheme.onSurface
                                            : colorScheme.onSurfaceVariant
                                                .withValues(alpha: 0.45),
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '選択中：${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日（${_weekdays[_selectedDate.weekday % 7]}）',
                style: theme.textTheme.bodyMedium,
              ),
            ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedDate),
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}

class _VisitDaysCard extends StatelessWidget {
  const _VisitDaysCard({required this.controller});

  final SettingsController controller;

  Future<void> _selectDate(BuildContext context) async {
    final initial = controller.settings.visitDate ?? DateTime.now();
    final selected = await _showJapaneseDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
      title: '来園日を選択',
      confirmText: '決定',
    );
    if (selected != null) controller.updateVisitDate(selected);
  }

  Future<void> _addDay(BuildContext context) async {
    final base = controller.settings.visitDate ?? DateTime.now();
    final selected = await _showJapaneseDatePicker(
      context: context,
      initialDate: base.add(const Duration(days: 1)),
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
      title: '追加する来園日を選択',
      confirmText: '追加',
    );
    if (selected != null) await controller.addVisitDay(selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month_outlined),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text('来園日ごとのプラン', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                FilledButton.tonalIcon(onPressed: () => _addDay(context), icon: const Icon(Icons.add), label: const Text('日を追加')),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('各日を独立した1日プランとして保存します。日付を切り替えると、やりたいこと・候補・予約・作成済みプランも切り替わります。', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final dayId in controller.visitDayIds)
                  InputChip(
                    selected: dayId == controller.activeVisitDayId,
                    avatar: const Icon(Icons.event_outlined, size: 18),
                    label: Text(controller.appState.settingsForVisitDay(dayId).visitDateLabel),
                    onPressed: () => controller.switchVisitDay(dayId),
                    onDeleted: controller.visitDayIds.length > 1 ? () => controller.removeVisitDay(dayId) : null,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => _selectDate(context),
              icon: const Icon(Icons.edit_calendar_outlined),
              label: Text(controller.settings.visitDate == null ? '現在の来園日を設定' : '現在の来園日を変更（${controller.settings.visitDateLabel}）'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsIntroCard extends StatelessWidget {
  const _SettingsIntroCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.auto_awesome_outlined,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '旅行の基本条件を設定します',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '上から順に設定してください。迷う項目は初期値のままでもプランを作成できます。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableSettingsSection extends StatelessWidget {
  const _ExpandableSettingsSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: AppSpacing.sm),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 19, color: colorScheme.onPrimaryContainer),
          ),
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          children: children,
        ),
      ),
    );
  }
}

class _ParkSettingsCard extends StatelessWidget {
  const _ParkSettingsCard({required this.settings, required this.onChanged});

  final TripSettings settings;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SettingsCardHeader(
            title: 'パーク',
            subtitle: '編集・プラン生成の対象パーク',
            icon: Icons.park_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('アプリバージョン ${AppVersion.displayName}'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _ParkChoiceButton(
                  label: 'ランド',
                  fullName: '東京ディズニーランド',
                  icon: Icons.castle_outlined,
                  selected: settings.parkId == 'tokyo_disneyland',
                  onPressed: () {
                    onChanged('tokyo_disneyland');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ParkChoiceButton(
                  label: 'シー',
                  fullName: '東京ディズニーシー',
                  icon: Icons.water_outlined,
                  selected: settings.parkId == 'tokyo_disneysea',
                  onPressed: () {
                    onChanged('tokyo_disneysea');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParkChoiceButton extends StatelessWidget {
  const _ParkChoiceButton({
    required this.label,
    required this.fullName,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final String fullName;
  final IconData icon;
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
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: selected ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: selected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: selected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, size: 18, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveDataSourceSettingsCard extends StatelessWidget {
  const _LiveDataSourceSettingsCard({
    required this.value,
    required this.isLoading,
    required this.onChanged,
  });

  final LiveDataSourceType value;
  final bool isLoading;
  final ValueChanged<LiveDataSourceType> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SettingsCardHeader(
            title: 'ライブデータ取得元',
            subtitle: '運営情報の取得方法を選択',
            icon: Icons.cloud_sync_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (isLoading)
            const LinearProgressIndicator()
          else
            DropdownButtonFormField<LiveDataSourceType>(
              initialValue: value,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '取得方法',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.cloud_sync_outlined),
              ),
              items: const [
                DropdownMenuItem(
                  value: LiveDataSourceType.mock,
                  child: Text('サンプルデータ'),
                ),
                DropdownMenuItem(
                  value: LiveDataSourceType.manual,
                  child: Text('手動入力'),
                ),
                DropdownMenuItem(
                  value: LiveDataSourceType.official,
                  child: Text('自動取得'),
                ),
              ],
              onChanged: (selection) {
                if (selection != null) onChanged(selection);
              },
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(switch (value) {
            LiveDataSourceType.mock => '動作確認用のサンプルデータを使用します。',
            LiveDataSourceType.manual => '公式アプリを見ながら手動入力した待ち時間を使用します。',
            LiveDataSourceType.official =>
              'ThemeParks.wikiから現在の待ち時間・運営状況を取得します。取得できない場合はサンプルデータへ切り替えます。',
          }, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Powered by ThemeParks.wiki',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitSummaryCard extends StatelessWidget {
  const _VisitSummaryCard({
    required this.settings,
    required this.onQueueArrivalTimePressed,
    required this.onHappyEntryTimePressed,
    required this.onEntryTimePressed,
    required this.onExitTimePressed,
    required this.onDecreasePeople,
    required this.onIncreasePeople,
  });

  final TripSettings settings;
  final VoidCallback onQueueArrivalTimePressed;
  final VoidCallback onHappyEntryTimePressed;
  final VoidCallback onEntryTimePressed;
  final VoidCallback onExitTimePressed;
  final VoidCallback onDecreasePeople;
  final VoidCallback onIncreasePeople;

  @override
  Widget build(BuildContext context) {
    final prediction = const EntryPredictionService().predict(settings);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SettingsCardHeader(
            title: '来園時間・人数',
            subtitle: '並び始める時刻から実際の行動開始を予測します',
            icon: Icons.schedule_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 430;
              final buttons = [
                _TimeSettingButton(
                  label: '並び開始',
                  time: settings.queueArrivalTimeLabel,
                  icon: Icons.people_alt_outlined,
                  onPressed: onQueueArrivalTimePressed,
                ),
                if (settings.hasHappyEntry)
                  _TimeSettingButton(
                    label: '先行入園',
                    time: settings.happyEntryTimeLabel,
                    icon: Icons.hotel_class_outlined,
                    onPressed: onHappyEntryTimePressed,
                  ),
                _TimeSettingButton(
                  label: '一般開園', 
                  time: settings.officialOpeningTimeLabel,
                  icon: Icons.door_front_door_outlined,
                  onPressed: onEntryTimePressed,
                ),
                _TimeSettingButton(
                  label: '退園',
                  time: settings.exitTimeLabel,
                  icon: Icons.logout,
                  onPressed: onExitTimePressed,
                ),
              ];

              if (stack) {
                return Column(
                  children: [
                    for (var index = 0; index < buttons.length; index++) ...[
                      SizedBox(width: double.infinity, child: buttons[index]),
                      if (index < buttons.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  for (var index = 0; index < buttons.length; index++) ...[
                    Expanded(child: buttons[index]),
                    if (index < buttons.length - 1)
                      const SizedBox(width: 8),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prediction.usesHappyEntryModel
                            ? '先行入園予測 ${prediction.expectedEntryLabel}'
                            : '予測入園 ${prediction.expectedEntryLabel}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '施設利用可能 ${prediction.firstFacilityAvailableLabel} '
                        '（入園後操作 ${prediction.postEntryOperationMinutes}分・'
                        '運営開始待ち ${prediction.facilityOpeningWaitMinutes}分）',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _PeopleCounter(
            people: settings.numberOfPeople,
            onDecrease: onDecreasePeople,
            onIncrease: onIncreasePeople,
          ),
        ],
      ),
    );
  }
}

class _TimeSettingButton extends StatelessWidget {
  const _TimeSettingButton({
    required this.label,
    required this.time,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final String time;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Icon(icon, size: 19, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      time,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_outlined,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeopleCounter extends StatelessWidget {
  const _PeopleCounter({
    required this.people,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int people;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.groups_outlined, size: 20, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '人数',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: '人数を減らす',
            onPressed: people <= 1 ? null : onDecrease,
            icon: const Icon(Icons.remove_circle_outline),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$people人',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: '人数を増やす',
            onPressed: people >= 10 ? null : onIncrease,
            icon: const Icon(Icons.add_circle_outline),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ServiceSettingsCard extends StatelessWidget {
  const _ServiceSettingsCard({
    required this.settings,
    required this.onHappyEntryChanged,
    required this.onAttractionDpaMaxUsesChanged,
    required this.onSingleRiderChanged,
    required this.onVacationPackageChanged,
    required this.onFreeDrinkChanged,
    required this.onAttractionVoucherChanged,
    required this.onShowVoucherChanged,
    required this.onRestaurantReservationChanged,
  });

  final TripSettings settings;
  final ValueChanged<bool> onHappyEntryChanged;
  final ValueChanged<int> onAttractionDpaMaxUsesChanged;
  final ValueChanged<bool> onSingleRiderChanged;
  final ValueChanged<bool> onVacationPackageChanged;
  final ValueChanged<bool> onFreeDrinkChanged;
  final ValueChanged<bool> onAttractionVoucherChanged;
  final ValueChanged<bool> onShowVoucherChanged;
  final ValueChanged<bool> onRestaurantReservationChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SettingsCardHeader(
            title: '利用サービス',
            subtitle: 'DPA上限など、当日使えるサービスを設定します',
            icon: Icons.confirmation_number_outlined,
          ),
          const SizedBox(height: 4),
          _CompactSwitchTile(
            title: 'ハッピーエントリー',
            subtitle: '対象ホテル宿泊者は一般開園より早く入園できます',
            icon: Icons.hotel_outlined,
            value: settings.hasHappyEntry,
            onChanged: onHappyEntryChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<int>(
            initialValue: settings.attractionDpaMaxUses,
            decoration: const InputDecoration(
              labelText: 'アトラクションDPA',
              helperText: 'AIが自動配分してよい上限です。ショーDPAは別扱いです。',
              prefixIcon: Icon(Icons.bolt),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 0, child: Text('使わない')),
              DropdownMenuItem(value: 1, child: Text('最大1個')),
              DropdownMenuItem(value: 2, child: Text('最大2個')),
              DropdownMenuItem(value: 3, child: Text('最大3個')),
            ],
            onChanged: (value) {
              if (value != null) {
                onAttractionDpaMaxUsesChanged(value);
              }
            },
          ),
          _CompactSwitchTile(
            title: 'シングルライダー',
            subtitle: '同行者と別れて空席を利用し、待ち時間を短縮します',
            icon: Icons.person_outline,
            value: settings.canUseSingleRider,
            onChanged: onSingleRiderChanged,
          ),
          const Divider(height: 20),
          _CompactSwitchTile(
            title: 'バケーションパッケージ',
            subtitle: '宿泊プランの特典を質問とスケジュールへ反映します',
            icon: Icons.card_travel_outlined,
            value: settings.usesVacationPackage,
            onChanged: onVacationPackageChanged,
          ),
          if (settings.usesVacationPackage) ...[
            _CompactSwitchTile(
              title: 'フリードリンク券',
              subtitle: '限定・店舗限定メニューの質問を表示',
              icon: Icons.local_drink_outlined,
              value: settings.usesFreeDrinkBenefit,
              onChanged: onFreeDrinkChanged,
            ),
            _CompactSwitchTile(
              title: 'アトラクション利用券',
              icon: Icons.attractions_outlined,
              value: settings.hasAttractionVoucher,
              onChanged: onAttractionVoucherChanged,
            ),
            _CompactSwitchTile(
              title: 'ショー鑑賞券',
              icon: Icons.theater_comedy_outlined,
              value: settings.hasShowVoucher,
              onChanged: onShowVoucherChanged,
            ),
            _CompactSwitchTile(
              title: 'レストラン予約',
              icon: Icons.restaurant_outlined,
              value: settings.hasRestaurantReservation,
              onChanged: onRestaurantReservationChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _MealSettingsCard extends StatelessWidget {
  const _MealSettingsCard({
    required this.settings,
    required this.onBreakfastChanged,
    required this.onLunchChanged,
    required this.onDinnerChanged,
  });

  final TripSettings settings;
  final ValueChanged<bool> onBreakfastChanged;
  final ValueChanged<bool> onLunchChanged;
  final ValueChanged<bool> onDinnerChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SettingsCardHeader(
            title: '食事の希望',
            subtitle: '必要な食事を一日の予定へ組み込みます',
            icon: Icons.restaurant_outlined,
          ),
          const SizedBox(height: 4),
          _CompactSwitchTile(
            title: '朝食',
            subtitle: '入園後から10:00までを朝食枠として扱う',
            icon: Icons.free_breakfast_outlined,
            value: settings.wantsBreakfast,
            onChanged: onBreakfastChanged,
          ),
          _CompactSwitchTile(
            title: '昼食',
            icon: Icons.lunch_dining_outlined,
            value: settings.wantsLunch,
            onChanged: onLunchChanged,
          ),
          _CompactSwitchTile(
            title: '夕食',
            icon: Icons.dinner_dining_outlined,
            value: settings.wantsDinner,
            onChanged: onDinnerChanged,
          ),
        ],
      ),
    );
  }
}

class _ConditionSettingsCard extends StatelessWidget {
  const _ConditionSettingsCard({
    required this.settings,
    required this.onRainyChanged,
    required this.onChildrenChanged,
  });

  final TripSettings settings;
  final ValueChanged<bool> onRainyChanged;
  final ValueChanged<bool> onChildrenChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SettingsCardHeader(
            title: '優先条件',
            subtitle: '該当する条件をAIの候補選びへ反映します',
            icon: Icons.tune_outlined,
          ),
          const SizedBox(height: 4),
          _CompactSwitchTile(
            title: '雨天',
            subtitle: '屋内施設を優先する',
            icon: Icons.umbrella_outlined,
            value: settings.isRainy,
            onChanged: onRainyChanged,
          ),
          _CompactSwitchTile(
            title: '子ども連れ',
            subtitle: '子ども向け施設を考慮する',
            icon: Icons.family_restroom_outlined,
            value: settings.hasChildren,
            onChanged: onChildrenChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingsCardHeader extends StatelessWidget {
  const _SettingsCardHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 19, color: colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactSwitchTile extends StatelessWidget {
  const _CompactSwitchTile({
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onChanged(!value);
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: value
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 18,
                  color: value
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.82,
                child: Switch(value: value, onChanged: onChanged),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DataFreshnessCard extends StatelessWidget {
  const _DataFreshnessCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: FutureBuilder<DataFreshnessInfo>(
        future: const DataFreshnessService().loadPerformanceScheduleInfo(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SettingsCardHeader(
                title: 'データ更新情報',
                subtitle: '公式情報を確認した日付',
                icon: Icons.update_outlined,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (info == null)
                const LinearProgressIndicator()
              else ...[
                Text('${info.label}：${info.dateLabel}'),
                const SizedBox(height: AppSpacing.xs),
                Text(info.note, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _BackupRestoreCard extends StatelessWidget {
  const _BackupRestoreCard({required this.controller});

  final SettingsController controller;

  Future<void> _showExport(BuildContext context) async {
    final value = controller.appState.exportBackupJson();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('バックアップを書き出す'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(child: SelectableText(value)),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('クリップボードへコピーしました。')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('コピー'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _showImport(BuildContext context) async {
    final textController = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('バックアップを復元する'),
        content: SizedBox(
          width: 620,
          child: TextField(
            controller: textController,
            maxLines: 14,
            decoration: const InputDecoration(
              hintText: 'コピーしたバックアップJSONを貼り付けてください。',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: const Text('復元'),
          ),
        ],
      ),
    );
    textController.dispose();

    if (value == null || value.trim().isEmpty || !context.mounted) {
      return;
    }

    try {
      await controller.appState.importBackupJson(value);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('バックアップを復元しました。')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('復元できませんでした：$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SettingsCardHeader(
            title: 'バックアップ・案内',
            subtitle: '端末変更やデータ破損に備える',
            icon: Icons.backup_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showExport(context),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('書き出す'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _showImport(context),
                  icon: const Icon(Icons.restore_outlined),
                  label: const Text('復元する'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ShareCenterScreen(),
                ),
              );
            },
            icon: const Icon(Icons.share_outlined),
            label: const Text('データ共有センターを開く'),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: () async {
              await controller.resetOnboarding();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('次回起動時に初回案内を表示します。')),
                );
              }
            },
            icon: const Icon(Icons.help_outline),
            label: const Text('初回案内をもう一度表示'),
          ),
        ],
      ),
    );
  }
}
