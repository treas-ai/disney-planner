import 'package:flutter/material.dart';

import '../../app/state/app_state.dart';
import '../../app/state/app_state_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../domain/entities/day_schedule.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/schedule_item.dart';
import '../../domain/entities/trip_settings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() {
    return _HomeScreenState();
  }
}

class _HomeScreenState extends State<HomeScreen> {
  AppState? _appState;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final appState = AppStateScope.of(context);

    if (identical(_appState, appState)) {
      return;
    }

    _appState?.removeListener(_refresh);

    _appState = appState;
    _appState!.addListener(_refresh);
  }

  @override
  void dispose() {
    _appState?.removeListener(_refresh);

    _scrollController.dispose();

    super.dispose();
  }

  void _refresh() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appState = _appState;

    if (appState == null) {
      return const AppScaffold(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final settings = appState.tripSettings;

    final selectedFacilities = appState.selectedFacilities
        .where((facility) => facility.parkId == settings.parkId)
        .toList(growable: false);

    final unavailableFacilities = selectedFacilities
        .where((facility) => !facility.isOpen)
        .toList(growable: false);

    final schedule = appState.daySchedule;

    return AppScaffold(
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        interactive: true,
        thickness: 5,
        radius: const Radius.circular(8),
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.only(right: 14, bottom: 96),
          children: [
            _HomeHeroCard(
              settings: settings,
              selectedFacilityCount: selectedFacilities.length,
              schedule: schedule,
            ),
            const SizedBox(height: AppSpacing.sm),
            LayoutBuilder(
              builder: (context, constraints) {
                final useTwoColumns = constraints.maxWidth >= 850;

                if (!useTwoColumns) {
                  return Column(
                    children: [
                      _NextActionCard(
                        settings: settings,
                        selectedFacilities: selectedFacilities,
                        unavailableFacilities: unavailableFacilities,
                        schedule: schedule,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _VisitSummaryCard(settings: settings),
                      const SizedBox(height: AppSpacing.sm),
                      _SelectedFacilitySummaryCard(
                        selectedFacilities: selectedFacilities,
                        unavailableFacilities: unavailableFacilities,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ScheduleSummaryCard(
                        settings: settings,
                        schedule: schedule,
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    _NextActionCard(
                      settings: settings,
                      selectedFacilities: selectedFacilities,
                      unavailableFacilities: unavailableFacilities,
                      schedule: schedule,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _VisitSummaryCard(settings: settings),
                              const SizedBox(height: AppSpacing.sm),
                              _SelectedFacilitySummaryCard(
                                selectedFacilities: selectedFacilities,
                                unavailableFacilities: unavailableFacilities,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _ScheduleSummaryCard(
                            settings: settings,
                            schedule: schedule,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeroCard extends StatelessWidget {
  const _HomeHeroCard({
    required this.settings,
    required this.selectedFacilityCount,
    required this.schedule,
  });

  final TripSettings settings;
  final int selectedFacilityCount;
  final DaySchedule? schedule;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final scheduleMatchesPark =
        schedule == null || schedule!.parkId == settings.parkId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;

          final information = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _parkIcon(settings.parkId),
                      size: 25,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '現在のプラン',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          _parkName(settings.parkId),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroInformationBadge(
                    icon: Icons.schedule_outlined,
                    label:
                        '${settings.entryTimeLabel}～${settings.exitTimeLabel}',
                  ),
                  _HeroInformationBadge(
                    icon: Icons.groups_outlined,
                    label: '${settings.numberOfPeople}人',
                  ),
                  _HeroInformationBadge(
                    icon: Icons.place_outlined,
                    label: '$selectedFacilityCount施設',
                  ),
                  _HeroInformationBadge(
                    icon: schedule != null && scheduleMatchesPark
                        ? Icons.check_circle_outline
                        : Icons.auto_awesome_outlined,
                    label: schedule != null && scheduleMatchesPark
                        ? '${schedule!.items.length}件生成済み'
                        : '未生成',
                  ),
                ],
              ),
            ],
          );

          if (compact) {
            return information;
          }

          return Row(
            children: [
              Expanded(child: information),
              const SizedBox(width: 24),
              Icon(
                schedule != null && scheduleMatchesPark
                    ? Icons.event_available_outlined
                    : Icons.route_outlined,
                size: 78,
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.24),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroInformationBadge extends StatelessWidget {
  const _HeroInformationBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({
    required this.settings,
    required this.selectedFacilities,
    required this.unavailableFacilities,
    required this.schedule,
  });

  final TripSettings settings;
  final List<Facility> selectedFacilities;
  final List<Facility> unavailableFacilities;
  final DaySchedule? schedule;

  @override
  Widget build(BuildContext context) {
    final action = _resolveAction();

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: action.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(action.icon, size: 22, color: action.foregroundColor),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '次にやること',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  action.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  action.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  _NextAction _resolveAction() {
    if (selectedFacilities.isEmpty) {
      return const _NextAction(
        title: '行きたい施設を選択',
        description: 'プラン編集画面で、行きたい施設を追加してください。',
        icon: Icons.add_location_alt_outlined,
        foregroundColor: Color(0xFF2457A6),
        backgroundColor: Color(0xFFEAF2FF),
      );
    }

    if (unavailableFacilities.isNotEmpty) {
      return _NextAction(
        title: '休止中施設を確認',
        description: '${unavailableFacilities.length}件の施設は、現在プランへ組み込めません。',
        icon: Icons.warning_amber_outlined,
        foregroundColor: const Color(0xFFC62828),
        backgroundColor: const Color(0xFFFFEBEE),
      );
    }

    if (schedule == null) {
      return const _NextAction(
        title: 'プランを生成',
        description: 'プラン確認画面で、選択した施設から一日の予定を作成してください。',
        icon: Icons.auto_awesome_outlined,
        foregroundColor: Color(0xFF6A3DA1),
        backgroundColor: Color(0xFFF2EAFE),
      );
    }

    if (schedule!.parkId != settings.parkId) {
      return const _NextAction(
        title: '現在のパークで再生成',
        description: '保存されているプランと、現在選択しているパークが異なります。',
        icon: Icons.sync_problem_outlined,
        foregroundColor: Color(0xFFC62828),
        backgroundColor: Color(0xFFFFEBEE),
      );
    }

    return const _NextAction(
      title: '当日の予定を確認',
      description: 'プランが生成されています。当日画面で時系列の予定を確認できます。',
      icon: Icons.event_available_outlined,
      foregroundColor: Color(0xFF287A4B),
      backgroundColor: Color(0xFFE8F5ED),
    );
  }
}

class _NextAction {
  const _NextAction({
    required this.title,
    required this.description,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
}

class _VisitSummaryCard extends StatelessWidget {
  const _VisitSummaryCard({required this.settings});

  final TripSettings settings;

  @override
  Widget build(BuildContext context) {
    final enabledServices = <String>[
      if (settings.hasHappyEntry) 'ハッピーエントリー',
      if (settings.canUseDpa) 'DPA',
      if (settings.canUsePriorityPass) 'プライオリティパス',
      if (settings.canUseSingleRider) 'シングルライダー',
    ];

    final meals = <String>[
      if (settings.wantsBreakfast) '朝食',
      if (settings.wantsLunch) '昼食',
      if (settings.wantsDinner) '夕食',
    ];

    final conditions = <String>[
      if (settings.isRainy) '雨天',
      if (settings.hasChildren) '子ども連れ',
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HomeCardHeader(title: '来園設定', icon: Icons.tune_outlined),
          const SizedBox(height: AppSpacing.sm),
          _SummaryRow(
            icon: Icons.login,
            title: '入園',
            value: settings.entryTimeLabel,
          ),
          _SummaryRow(
            icon: Icons.logout,
            title: '退園',
            value: settings.exitTimeLabel,
          ),
          _SummaryRow(
            icon: Icons.groups_outlined,
            title: '人数',
            value: '${settings.numberOfPeople}人',
          ),
          _SummaryRow(
            icon: Icons.confirmation_number_outlined,
            title: '利用サービス',
            value: enabledServices.isEmpty
                ? '利用しない'
                : enabledServices.join('・'),
          ),
          _SummaryRow(
            icon: Icons.restaurant_outlined,
            title: '食事',
            value: meals.isEmpty ? '設定なし' : meals.join('・'),
          ),
          _SummaryRow(
            icon: Icons.info_outline,
            title: '条件',
            value: conditions.isEmpty ? '特になし' : conditions.join('・'),
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _SelectedFacilitySummaryCard extends StatelessWidget {
  const _SelectedFacilitySummaryCard({
    required this.selectedFacilities,
    required this.unavailableFacilities,
  });

  final List<Facility> selectedFacilities;
  final List<Facility> unavailableFacilities;

  @override
  Widget build(BuildContext context) {
    final categoryCounts = <String, int>{};

    for (final facility in selectedFacilities) {
      final label = _categoryLabel(facility);

      categoryCounts[label] = (categoryCounts[label] ?? 0) + 1;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeCardHeader(
            title: '選択済み施設',
            icon: Icons.playlist_add_check_outlined,
            trailing: '${selectedFacilities.length}件',
          ),
          const SizedBox(height: AppSpacing.sm),
          if (selectedFacilities.isEmpty)
            Text(
              '施設はまだ選択されていません。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in categoryCounts.entries)
                  _CountBadge(label: entry.key, count: entry.value),
              ],
            ),
            if (unavailableFacilities.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${unavailableFacilities.length}件は休止中または追加不可です。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _categoryLabel(Facility facility) {
    if (facility.isShop) {
      return 'ショップ';
    }

    if (facility.isRestaurant) {
      return 'レストラン';
    }

    return switch (facility.category.name) {
      'attraction' => 'アトラクション',
      'show' => 'ショー',
      'parade' => 'パレード',
      'greeting' => 'グリーティング',
      'service' => 'サービス',
      _ => facility.category.label,
    };
  }
}

class _ScheduleSummaryCard extends StatelessWidget {
  const _ScheduleSummaryCard({required this.settings, required this.schedule});

  final TripSettings settings;
  final DaySchedule? schedule;

  @override
  Widget build(BuildContext context) {
    final scheduleMatchesPark =
        schedule != null && schedule!.parkId == settings.parkId;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeCardHeader(
            title: '生成済みプラン',
            icon: Icons.route_outlined,
            trailing: scheduleMatchesPark ? '${schedule!.items.length}件' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (schedule == null)
            const _ScheduleEmptyMessage(
              icon: Icons.auto_awesome_outlined,
              title: 'プラン未生成',
              message: 'プラン確認画面から一日の予定を生成してください。',
            )
          else if (!scheduleMatchesPark)
            const _ScheduleEmptyMessage(
              icon: Icons.sync_problem_outlined,
              title: '別のパークのプランです',
              message: '現在選択しているパークでプランを再生成してください。',
            )
          else if (schedule!.items.isEmpty)
            const _ScheduleEmptyMessage(
              icon: Icons.event_busy_outlined,
              title: '予定がありません',
              message: '条件や施設を見直して再生成してください。',
            )
          else ...[
            _ScheduleOverview(schedule: schedule!),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '最初の予定',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            _FirstScheduleItem(item: schedule!.items.first),
            if (schedule!.items.length > 1) ...[
              const SizedBox(height: 8),
              Text(
                'ほか${schedule!.items.length - 1}件の予定があります。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ScheduleOverview extends StatelessWidget {
  const _ScheduleOverview({required this.schedule});

  final DaySchedule schedule;

  @override
  Widget build(BuildContext context) {
    final firstItem = schedule.items.first;
    final lastItem = schedule.items.last;

    return Row(
      children: [
        Expanded(
          child: _ScheduleMetric(
            label: '開始',
            value: firstItem.startTimeLabel,
            icon: Icons.play_arrow_outlined,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _ScheduleMetric(
            label: '終了',
            value: lastItem.endTimeLabel,
            icon: Icons.stop_outlined,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _ScheduleMetric(
            label: '予定',
            value: '${schedule.items.length}件',
            icon: Icons.event_note_outlined,
          ),
        ),
      ],
    );
  }
}

class _ScheduleMetric extends StatelessWidget {
  const _ScheduleMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 17, color: colorScheme.primary),
          const SizedBox(height: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _FirstScheduleItem extends StatelessWidget {
  const _FirstScheduleItem({required this.item});

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              item.startTimeLabel,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  item.type.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
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

class _ScheduleEmptyMessage extends StatelessWidget {
  const _ScheduleEmptyMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 7),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeCardHeader extends StatelessWidget {
  const _HomeCardHeader({
    required this.title,
    required this.icon,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 21),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.title,
    required this.value,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              SizedBox(
                width: 86,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: colorScheme.outlineVariant),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        '$label $count',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
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
