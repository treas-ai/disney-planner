import 'package:flutter/material.dart';

import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/loading_view.dart';
import '../../domain/entities/trip_settings.dart';
import '../../domain/enums/live_data_source_type.dart';
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
      helpText: '入園時刻を選択',
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
              onEntryTimePressed: _selectEntryTime,
              onExitTimePressed: _selectExitTime,
            );
          }

          return _MobileSettingsLayout(
            settings: settings,
            controller: controller,
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
    required this.onEntryTimePressed,
    required this.onExitTimePressed,
  });

  final TripSettings settings;
  final SettingsController controller;
  final VoidCallback onEntryTimePressed;
  final VoidCallback onExitTimePressed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(right: 12, bottom: 96),
      children: [
        _ParkSettingsCard(settings: settings, onChanged: controller.updatePark),
        const SizedBox(height: AppSpacing.sm),
        _LiveDataSourceSettingsCard(
          value: controller.liveDataSource,
          isLoading: controller.isLoadingLiveDataSource,
          onChanged: controller.updateLiveDataSource,
        ),
        const SizedBox(height: AppSpacing.sm),
        _VisitSummaryCard(
          settings: settings,
          onEntryTimePressed: onEntryTimePressed,
          onExitTimePressed: onExitTimePressed,
          onDecreasePeople: controller.decreasePeople,
          onIncreasePeople: controller.increasePeople,
        ),
        const SizedBox(height: AppSpacing.sm),
        _ServiceSettingsCard(
          settings: settings,
          onHappyEntryChanged: controller.updateHappyEntry,
          onDpaChanged: controller.updateDpa,
          onPriorityPassChanged: controller.updatePriorityPass,
          onSingleRiderChanged: controller.updateSingleRider,
        ),
        const SizedBox(height: AppSpacing.sm),
        _MealSettingsCard(
          settings: settings,
          onBreakfastChanged: controller.updateBreakfast,
          onLunchChanged: controller.updateLunch,
          onDinnerChanged: controller.updateDinner,
        ),
        const SizedBox(height: AppSpacing.sm),
        _ConditionSettingsCard(
          settings: settings,
          onRainyChanged: controller.updateRainy,
          onChildrenChanged: controller.updateChildren,
        ),
      ],
    );
  }
}

class _DesktopSettingsLayout extends StatelessWidget {
  const _DesktopSettingsLayout({
    required this.settings,
    required this.controller,
    required this.onEntryTimePressed,
    required this.onExitTimePressed,
  });

  final TripSettings settings;
  final SettingsController controller;
  final VoidCallback onEntryTimePressed;
  final VoidCallback onExitTimePressed;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 14, bottom: 48),
      child: Row(
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
                _LiveDataSourceSettingsCard(
                  value: controller.liveDataSource,
                  isLoading: controller.isLoadingLiveDataSource,
                  onChanged: controller.updateLiveDataSource,
                ),
                const SizedBox(height: AppSpacing.sm),
                _VisitSummaryCard(
                  settings: settings,
                  onEntryTimePressed: onEntryTimePressed,
                  onExitTimePressed: onExitTimePressed,
                  onDecreasePeople: controller.decreasePeople,
                  onIncreasePeople: controller.increasePeople,
                ),
                const SizedBox(height: AppSpacing.sm),
                _ConditionSettingsCard(
                  settings: settings,
                  onRainyChanged: controller.updateRainy,
                  onChildrenChanged: controller.updateChildren,
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
                  onDpaChanged: controller.updateDpa,
                  onPriorityPassChanged: controller.updatePriorityPass,
                  onSingleRiderChanged: controller.updateSingleRider,
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
        ],
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
            SegmentedButton<LiveDataSourceType>(
              segments: const [
                ButtonSegment(
                  value: LiveDataSourceType.mock,
                  label: Text('サンプル'),
                  icon: Icon(Icons.science_outlined),
                ),
                ButtonSegment(
                  value: LiveDataSourceType.manual,
                  label: Text('手動入力'),
                  icon: Icon(Icons.edit_note_outlined),
                ),
                ButtonSegment(
                  value: LiveDataSourceType.official,
                  label: Text('自動取得'),
                  icon: Icon(Icons.cloud_outlined),
                ),
              ],
              selected: {value},
              onSelectionChanged: (selection) {
                onChanged(selection.first);
              },
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            switch (value) {
              LiveDataSourceType.mock =>
                '動作確認用のサンプルデータを使用します。',
              LiveDataSourceType.manual =>
                '公式アプリを見ながら手動入力した待ち時間を使用します。',
              LiveDataSourceType.official =>
                '自動取得の接続先は準備中です。取得できない場合はサンプルデータへ切り替えます。',
            },
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _VisitSummaryCard extends StatelessWidget {
  const _VisitSummaryCard({
    required this.settings,
    required this.onEntryTimePressed,
    required this.onExitTimePressed,
    required this.onDecreasePeople,
    required this.onIncreasePeople,
  });

  final TripSettings settings;
  final VoidCallback onEntryTimePressed;
  final VoidCallback onExitTimePressed;
  final VoidCallback onDecreasePeople;
  final VoidCallback onIncreasePeople;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SettingsCardHeader(
            title: '来園時間・人数',
            subtitle: '滞在時間とグループ人数',
            icon: Icons.schedule_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _TimeSettingButton(
                  label: '入園',
                  time: settings.entryTimeLabel,
                  icon: Icons.login,
                  onPressed: onEntryTimePressed,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TimeSettingButton(
                  label: '退園',
                  time: settings.exitTimeLabel,
                  icon: Icons.logout,
                  onPressed: onExitTimePressed,
                ),
              ),
            ],
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
    required this.onDpaChanged,
    required this.onPriorityPassChanged,
    required this.onSingleRiderChanged,
  });

  final TripSettings settings;
  final ValueChanged<bool> onHappyEntryChanged;
  final ValueChanged<bool> onDpaChanged;
  final ValueChanged<bool> onPriorityPassChanged;
  final ValueChanged<bool> onSingleRiderChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SettingsCardHeader(
            title: '利用サービス',
            subtitle: 'プラン作成時に利用可能なサービス',
            icon: Icons.confirmation_number_outlined,
          ),
          const SizedBox(height: 4),
          _CompactSwitchTile(
            title: 'ハッピーエントリー',
            subtitle: '対象ホテル宿泊者向けの早期入園',
            icon: Icons.hotel_outlined,
            value: settings.hasHappyEntry,
            onChanged: onHappyEntryChanged,
          ),
          _CompactSwitchTile(
            title: 'ディズニー・プレミアアクセス',
            subtitle: '有料の時間指定サービス',
            icon: Icons.bolt,
            value: settings.canUseDpa,
            onChanged: onDpaChanged,
          ),
          _CompactSwitchTile(
            title: 'プライオリティパス',
            subtitle: '無料の優先案内サービス',
            icon: Icons.confirmation_number_outlined,
            value: settings.canUsePriorityPass,
            onChanged: onPriorityPassChanged,
          ),
          _CompactSwitchTile(
            title: 'シングルライダー',
            subtitle: '同行者と別れて空席を利用',
            icon: Icons.person_outline,
            value: settings.canUseSingleRider,
            onChanged: onSingleRiderChanged,
          ),
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
            title: '食事希望',
            subtitle: 'スケジュールに組み込む食事',
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
            title: '来園条件',
            subtitle: '施設の優先順位に影響する条件',
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
