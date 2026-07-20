import 'package:flutter/material.dart';

import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/section_title.dart';
import '../../domain/entities/trip_settings.dart';
import 'settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SettingsController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_controller == null) {
      final appState = AppStateScope.of(context);

      _controller = SettingsController(appState);
      _controller!.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_refresh);
    _controller?.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {});
  }

  Future<void> _selectEntryTime() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final current = TimeOfDay(
      hour: controller.settings.entryTimeHour,
      minute: controller.settings.entryTimeMinute,
    );

    final selected = await showTimePicker(
      context: context,
      initialTime: current,
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

    final current = TimeOfDay(
      hour: controller.settings.exitTimeHour,
      minute: controller.settings.exitTimeMinute,
    );

    final selected = await showTimePicker(
      context: context,
      initialTime: current,
    );

    if (selected != null) {
      controller.updateExitTime(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller == null) {
      return const AppScaffold(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final settings = controller.settings;

    return AppScaffold(
      child: ListView(
        children: [
          const SectionTitle(
            title: '設定',
            subtitle: 'AIプラン生成に使う来園条件を設定します。',
            icon: AppIcons.settingsSelected,
          ),
          _ParkSettingsCard(
            settings: settings,
            onChanged: controller.updatePark,
          ),
          _TimeSettingsCard(
            settings: settings,
            onEntryTimePressed: _selectEntryTime,
            onExitTimePressed: _selectExitTime,
          ),
          _PeopleSettingsCard(
            settings: settings,
            onDecrease: controller.decreasePeople,
            onIncrease: controller.increasePeople,
          ),
          _ServiceSettingsCard(
            settings: settings,
            onHappyEntryChanged: controller.updateHappyEntry,
            onDpaChanged: controller.updateDpa,
            onPriorityPassChanged: controller.updatePriorityPass,
            onSingleRiderChanged: controller.updateSingleRider,
          ),
          _MealSettingsCard(
            settings: settings,
            onLunchChanged: controller.updateLunch,
            onDinnerChanged: controller.updateDinner,
          ),
          _ConditionSettingsCard(
            settings: settings,
            onRainyChanged: controller.updateRainy,
            onChildrenChanged: controller.updateChildren,
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
          Text('パーク設定', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: settings.parkId,
            decoration: const InputDecoration(
              labelText: 'パーク',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'tokyo_disneyland',
                child: Text('東京ディズニーランド'),
              ),
              DropdownMenuItem(
                value: 'tokyo_disneysea',
                child: Text('東京ディズニーシー'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                onChanged(value);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _TimeSettingsCard extends StatelessWidget {
  const _TimeSettingsCard({
    required this.settings,
    required this.onEntryTimePressed,
    required this.onExitTimePressed,
  });

  final TripSettings settings;
  final VoidCallback onEntryTimePressed;
  final VoidCallback onExitTimePressed;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('時間設定', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: '入園 ${settings.entryTimeLabel}',
                  icon: Icons.login,
                  onPressed: onEntryTimePressed,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: '退園 ${settings.exitTimeLabel}',
                  icon: Icons.logout,
                  onPressed: onExitTimePressed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeopleSettingsCard extends StatelessWidget {
  const _PeopleSettingsCard({
    required this.settings,
    required this.onDecrease,
    required this.onIncrease,
  });

  final TripSettings settings;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Text(
              '人数：${settings.numberOfPeople}人',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            onPressed: onDecrease,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          IconButton(
            onPressed: onIncrease,
            icon: const Icon(Icons.add_circle_outline),
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
          Text('サービス利用設定', style: Theme.of(context).textTheme.titleLarge),
          SwitchListTile(
            title: const Text('Happy Entry'),
            value: settings.hasHappyEntry,
            onChanged: onHappyEntryChanged,
          ),
          SwitchListTile(
            title: const Text('DPA'),
            value: settings.canUseDpa,
            onChanged: onDpaChanged,
          ),
          SwitchListTile(
            title: const Text('Priority Pass'),
            value: settings.canUsePriorityPass,
            onChanged: onPriorityPassChanged,
          ),
          SwitchListTile(
            title: const Text('Single Rider'),
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
    required this.onLunchChanged,
    required this.onDinnerChanged,
  });

  final TripSettings settings;
  final ValueChanged<bool> onLunchChanged;
  final ValueChanged<bool> onDinnerChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('食事設定', style: Theme.of(context).textTheme.titleLarge),
          SwitchListTile(
            title: const Text('昼食あり'),
            value: settings.wantsLunch,
            onChanged: onLunchChanged,
          ),
          SwitchListTile(
            title: const Text('夕食あり'),
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
          Text('条件設定', style: Theme.of(context).textTheme.titleLarge),
          SwitchListTile(
            title: const Text('雨'),
            value: settings.isRainy,
            onChanged: onRainyChanged,
          ),
          SwitchListTile(
            title: const Text('子供あり'),
            value: settings.hasChildren,
            onChanged: onChildrenChanged,
          ),
        ],
      ),
    );
  }
}
