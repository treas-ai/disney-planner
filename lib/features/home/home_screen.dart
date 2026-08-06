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

part 'widgets/home_hero_card.part.dart';
part 'widgets/home_progress_card.part.dart';
part 'widgets/home_visit_summary_card.part.dart';
part 'widgets/home_schedule_card.part.dart';
part 'widgets/home_shared_widgets.part.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onWishListPressed,
    required this.onEditPlanPressed,
    required this.onReviewPlanPressed,
    required this.onTodayPlanPressed,
    required this.onSettingsPressed,
  });

  final VoidCallback onWishListPressed;
  final VoidCallback onEditPlanPressed;
  final VoidCallback onReviewPlanPressed;
  final VoidCallback onTodayPlanPressed;
  final VoidCallback onSettingsPressed;

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

    final hasCurrentSchedule =
        schedule != null && schedule.parkId == settings.parkId;

    final nextAction = _resolveHomeAction(
      selectedFacilities: selectedFacilities,
      unavailableFacilities: unavailableFacilities,
      schedule: schedule,
      settings: settings,
    );

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
                      _HomeProgressCard(
                        action: nextAction,
                        selectedWishCount: appState.selectedWishCount,
                        selectedFacilityCount: selectedFacilities.length,
                        hasCurrentSchedule: hasCurrentSchedule,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _VisitSummaryCard(
                        settings: settings,
                        onSettingsPressed: widget.onSettingsPressed,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SelectedFacilitySummaryCard(
                        selectedFacilities: selectedFacilities,
                        unavailableFacilities: unavailableFacilities,
                        onEditPlanPressed: widget.onEditPlanPressed,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ScheduleSummaryCard(
                        settings: settings,
                        schedule: schedule,
                        onReviewPlanPressed: widget.onReviewPlanPressed,
                        onTodayPlanPressed: widget.onTodayPlanPressed,
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    _HomeProgressCard(
                        action: nextAction,
                        selectedWishCount: appState.selectedWishCount,
                        selectedFacilityCount: selectedFacilities.length,
                        hasCurrentSchedule: hasCurrentSchedule,
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _VisitSummaryCard(
                                settings: settings,
                                onSettingsPressed: widget.onSettingsPressed,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _SelectedFacilitySummaryCard(
                                selectedFacilities: selectedFacilities,
                                unavailableFacilities: unavailableFacilities,
                                onEditPlanPressed: widget.onEditPlanPressed,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _ScheduleSummaryCard(
                            settings: settings,
                            schedule: schedule,
                            onReviewPlanPressed: widget.onReviewPlanPressed,
                            onTodayPlanPressed: widget.onTodayPlanPressed,
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

  _HomeAction _resolveHomeAction({
    required List<Facility> selectedFacilities,
    required List<Facility> unavailableFacilities,
    required DaySchedule? schedule,
    required TripSettings settings,
  }) {
    if (_appState?.selectedWishCount == 0) {
      return _HomeAction(
        title: 'やりたいことを選択',
        description: '乗りたい・見たい・飲みたい・食べたいものを先に選びます。',
        buttonLabel: 'やりたいことを開く',
        icon: Icons.favorite_border,
        foregroundColor: const Color(0xFF8A2D5C),
        backgroundColor: const Color(0xFFFFEAF4),
      );
    }

    if (selectedFacilities.isEmpty) {
      return _HomeAction(
        title: 'プラン候補を確認',
        description: 'やりたいことの選択内容を施設へ反映するか、候補を手動で追加してください。',
        buttonLabel: '候補確認を開く',
        icon: Icons.checklist_outlined,
        foregroundColor: const Color(0xFF2457A6),
        backgroundColor: const Color(0xFFEAF2FF),
      );
    }

    if (unavailableFacilities.isNotEmpty) {
      return _HomeAction(
        title: '休止中施設を確認',
        description: '${unavailableFacilities.length}件の施設は、現在プランへ組み込めません。',
        buttonLabel: '選択施設を確認',
        icon: Icons.warning_amber_outlined,
        foregroundColor: const Color(0xFFC62828),
        backgroundColor: const Color(0xFFFFEBEE),
      );
    }

    if (schedule == null) {
      return _HomeAction(
        title: 'プランを生成',
        description: '選択した施設から一日の予定を作成します。',
        buttonLabel: 'プラン確認へ',
        icon: Icons.auto_awesome_outlined,
        foregroundColor: const Color(0xFF6A3DA1),
        backgroundColor: const Color(0xFFF2EAFE),
      );
    }

    if (schedule.parkId != settings.parkId) {
      return _HomeAction(
        title: '現在のパークで再生成',
        description: '保存されているプランと、現在選択しているパークが異なります。',
        buttonLabel: 'プラン確認へ',
        icon: Icons.sync_problem_outlined,
        foregroundColor: const Color(0xFFC62828),
        backgroundColor: const Color(0xFFFFEBEE),
      );
    }

    return _HomeAction(
      title: '当日の予定を確認',
      description: 'プランが生成されています。当日画面で時系列の予定を確認できます。',
      buttonLabel: '当日の予定へ',
      icon: Icons.event_available_outlined,
      foregroundColor: const Color(0xFF287A4B),
      backgroundColor: const Color(0xFFE8F5ED),
    );
  }
}

