import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/facility.dart';
import '../../../domain/entities/plan_preference.dart';
import '../../../domain/enums/facility_access_method.dart';
import '../../../domain/enums/facility_category.dart';
import '../live_approach_guidance.dart';
import '../live_controller.dart';
import '../live_models.dart';
import '../live_recommendation.dart';

class LiveWaitTimeListPanel extends StatelessWidget {
  const LiveWaitTimeListPanel({
    super.key,
    required this.controller,
    required this.now,
    required this.onEditPressed,
  });

  final LiveController controller;
  final DateTime now;
  final ValueChanged<Facility> onEditPressed;

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries();

    final recommendationResult = const LiveRecommendationEvaluator().evaluate(
      controller: controller,
    );

    final approachGuidance = const LiveApproachGuidanceResolver().resolve(
      controller: controller,
    );

    if (entries.isEmpty &&
        !recommendationResult.hasRecommendations &&
        approachGuidance == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (approachGuidance != null)
          _ApproachGuidancePanel(guidance: approachGuidance),
        if (approachGuidance != null && recommendationResult.hasRecommendations)
          const SizedBox(height: AppSpacing.sm),
        if (recommendationResult.hasRecommendations)
          _LiveRecommendationPanel(
            result: recommendationResult,
            onEditPressed: onEditPressed,
          ),
        if ((approachGuidance != null ||
                recommendationResult.hasRecommendations) &&
            entries.isNotEmpty)
          const SizedBox(height: AppSpacing.sm),
        if (entries.isNotEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PanelHeader(
                  facilityCount: entries.length,
                  onRefreshPressed: controller.reloadWaitTimes,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '当日プランに含まれるアトラクションの待ち時間です。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (var index = 0; index < entries.length; index++) ...[
                  _WaitTimeListItem(
                    entry: entries[index],
                    now: now,
                    onEditPressed: () {
                      onEditPressed(entries[index].facility);
                    },
                  ),
                  if (index < entries.length - 1)
                    const Divider(height: AppSpacing.lg),
                ],
              ],
            ),
          ),
      ],
    );
  }

  List<_LiveWaitTimeListEntry> _buildEntries() {
    final schedule = controller.schedule;

    if (schedule == null || !controller.scheduleMatchesCurrentPark) {
      return const [];
    }

    final facilitiesById = <String, Facility>{};

    for (final item in schedule.items) {
      final facility = controller.facilityById(item.facilityId);

      if (facility == null ||
          facility.category != FacilityCategory.attraction) {
        continue;
      }

      facilitiesById[facility.id] = facility;
    }

    final entries = facilitiesById.values
        .map(
          (facility) => _LiveWaitTimeListEntry(
            facility: facility,
            preference: controller.preferenceByFacilityId(facility.id),
            waitTime: _resolveWaitTime(facility),
          ),
        )
        .toList(growable: true);

    entries.sort((left, right) {
      final leftMinutes = left.waitTime.waitMinutes;

      final rightMinutes = right.waitTime.waitMinutes;

      if (leftMinutes == null && rightMinutes == null) {
        return left.facility.name.compareTo(right.facility.name);
      }

      if (leftMinutes == null) {
        return 1;
      }

      if (rightMinutes == null) {
        return -1;
      }

      final waitComparison = leftMinutes.compareTo(rightMinutes);

      if (waitComparison != 0) {
        return waitComparison;
      }

      return left.facility.name.compareTo(right.facility.name);
    });

    return List<_LiveWaitTimeListEntry>.unmodifiable(entries);
  }

  LiveWaitTimeDisplay _resolveWaitTime(Facility facility) {
    final preference = controller.preferenceByFacilityId(facility.id);

    final passWaitTime = _passWaitTime(
      facility: facility,
      preference: preference,
    );

    if (passWaitTime != null) {
      return passWaitTime;
    }

    final manualWaitTime = controller.manualWaitTimeByFacilityId(facility.id);

    if (manualWaitTime != null) {
      return LiveWaitTimeDisplay(
        kind: LiveWaitTimeKind.manual,
        label: '手動入力',
        waitMinutes: manualWaitTime.waitMinutes,
        isStale: manualWaitTime.isStaleAt(now),
        updatedAt: manualWaitTime.updatedAt,
      );
    }

    final facilityWaitMinutes = facility.waitTime?.minutes;

    if (facilityWaitMinutes != null) {
      return LiveWaitTimeDisplay(
        kind: LiveWaitTimeKind.facilityEstimate,
        label: '施設データの目安',
        waitMinutes: facilityWaitMinutes,
        isStale: false,
      );
    }

    return const LiveWaitTimeDisplay(
      kind: LiveWaitTimeKind.unknown,
      label: '待ち時間不明',
      waitMinutes: null,
      isStale: false,
    );
  }

  LiveWaitTimeDisplay? _passWaitTime({
    required Facility facility,
    required PlanPreference? preference,
  }) {
    final accessMethod =
        preference?.accessMethod ?? FacilityAccessMethod.standby;

    return switch (accessMethod) {
      FacilityAccessMethod.dpa when facility.supportsDpa =>
        const LiveWaitTimeDisplay(
          kind: LiveWaitTimeKind.passEstimate,
          label: 'DPA利用時の目安',
          waitMinutes: 10,
          isStale: false,
        ),
      FacilityAccessMethod.priorityPass when facility.supportsPriorityPass =>
        const LiveWaitTimeDisplay(
          kind: LiveWaitTimeKind.passEstimate,
          label: 'プライオリティパス利用時の目安',
          waitMinutes: 15,
          isStale: false,
        ),
      FacilityAccessMethod.standbyPass when facility.supportsStandbyPass =>
        const LiveWaitTimeDisplay(
          kind: LiveWaitTimeKind.passEstimate,
          label: 'スタンバイパス利用時の目安',
          waitMinutes: 20,
          isStale: false,
        ),
      FacilityAccessMethod.entryRequest when facility.requiresEntryRequest =>
        const LiveWaitTimeDisplay(
          kind: LiveWaitTimeKind.passEstimate,
          label: 'エントリー受付利用時の目安',
          waitMinutes: 15,
          isStale: false,
        ),
      _ => null,
    };
  }
}

class _ApproachGuidancePanel extends StatelessWidget {
  const _ApproachGuidancePanel({required this.guidance});

  final LiveApproachGuidance guidance;

  @override
  Widget build(BuildContext context) {
    final style = _visualStyle(guidance.stage);

    return AppCard(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: style.backgroundColor,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: style.borderColor,
            width: guidance.isUrgent ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: style.iconBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    style.icon,
                    size: 24,
                    color: style.foregroundColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guidance.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: style.foregroundColor,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        guidance.item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: style.foregroundColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!guidance.isInProgress)
                  _CountdownBadge(
                    minutes: guidance.minutesUntilStart,
                    foregroundColor: style.foregroundColor,
                    backgroundColor: style.iconBackgroundColor,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              guidance.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: style.foregroundColor,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _ApproachBadge(
                  icon: Icons.schedule_outlined,
                  label: guidance.item.timeRangeLabel,
                  foregroundColor: style.foregroundColor,
                  backgroundColor: style.iconBackgroundColor,
                ),
                _ApproachBadge(
                  icon: Icons.directions_walk_outlined,
                  label: '推奨移動 ${guidance.recommendedLeadMinutes}分前',
                  foregroundColor: style.foregroundColor,
                  backgroundColor: style.iconBackgroundColor,
                ),
                if (!guidance.isInProgress &&
                    guidance.minutesUntilRecommendedDeparture > 0)
                  _ApproachBadge(
                    icon: Icons.timer_outlined,
                    label:
                        '移動開始まであと'
                        '${guidance.minutesUntilRecommendedDeparture}分',
                    foregroundColor: style.foregroundColor,
                    backgroundColor: style.iconBackgroundColor,
                  ),
              ],
            ),
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: style.iconBackgroundColor,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 17,
                    color: style.foregroundColor,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      guidance.reason,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: style.foregroundColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _ApproachVisualStyle _visualStyle(LiveApproachStage stage) {
    return switch (stage) {
      LiveApproachStage.normal => const _ApproachVisualStyle(
        icon: Icons.event_outlined,
        foregroundColor: Color(0xFF536873),
        backgroundColor: Color(0xFFF4F7F8),
        iconBackgroundColor: Color(0xFFE6EEF1),
        borderColor: Color(0xFFC7D4D9),
      ),
      LiveApproachStage.prepare => const _ApproachVisualStyle(
        icon: Icons.notifications_outlined,
        foregroundColor: Color(0xFF2457A6),
        backgroundColor: Color(0xFFEAF2FF),
        iconBackgroundColor: Color(0xFFD7E7FF),
        borderColor: Color(0xFF9ABBEA),
      ),
      LiveApproachStage.recommended => const _ApproachVisualStyle(
        icon: Icons.directions_walk_outlined,
        foregroundColor: Color(0xFF287A4B),
        backgroundColor: Color(0xFFE8F5ED),
        iconBackgroundColor: Color(0xFFD2ECD9),
        borderColor: Color(0xFFA5D6B7),
      ),
      LiveApproachStage.moveNow => const _ApproachVisualStyle(
        icon: Icons.navigation_outlined,
        foregroundColor: Color(0xFF8A6D00),
        backgroundColor: Color(0xFFFFF8E1),
        iconBackgroundColor: Color(0xFFFFEDB0),
        borderColor: Color(0xFFFFD54F),
      ),
      LiveApproachStage.hurry => const _ApproachVisualStyle(
        icon: Icons.directions_run_outlined,
        foregroundColor: Color(0xFFB45309),
        backgroundColor: Color(0xFFFFF3E0),
        iconBackgroundColor: Color(0xFFFFE0B2),
        borderColor: Color(0xFFFFB74D),
      ),
      LiveApproachStage.imminent => const _ApproachVisualStyle(
        icon: Icons.warning_amber_outlined,
        foregroundColor: Color(0xFFC62828),
        backgroundColor: Color(0xFFFFEBEE),
        iconBackgroundColor: Color(0xFFFFCDD2),
        borderColor: Color(0xFFEF9A9A),
      ),
      LiveApproachStage.inProgress => const _ApproachVisualStyle(
        icon: Icons.play_circle_outline,
        foregroundColor: Color(0xFF6A3DA1),
        backgroundColor: Color(0xFFF2EAFE),
        iconBackgroundColor: Color(0xFFE1CFF7),
        borderColor: Color(0xFFC9AEEF),
      ),
    };
  }
}

class _CountdownBadge extends StatelessWidget {
  const _CountdownBadge({
    required this.minutes,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final int minutes;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 58),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$minutes',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '分後',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApproachBadge extends StatelessWidget {
  const _ApproachBadge({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveRecommendationPanel extends StatelessWidget {
  const _LiveRecommendationPanel({
    required this.result,
    required this.onEditPressed,
  });

  final LiveRecommendationResult result;
  final ValueChanged<Facility> onEditPressed;

  @override
  Widget build(BuildContext context) {
    final best = result.bestRecommendation;

    if (best == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    final visualStyle = _recommendationStyle(best.level);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: visualStyle.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  visualStyle.icon,
                  size: 23,
                  color: visualStyle.foregroundColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今のおすすめ',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '現在時刻と待ち時間から判定',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _RecommendationScoreBadge(recommendation: best),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: visualStyle.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: visualStyle.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  best.facility.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: visualStyle.foregroundColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  best.level.starLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: visualStyle.foregroundColor,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  best.level.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: visualStyle.foregroundColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _RecommendationInformationBadge(
                      icon: Icons.groups_outlined,
                      label: best.waitTime.waitMinutes == null
                          ? '待ち時間不明'
                          : '待ち時間 '
                                '${best.waitTime.waitMinutes}分',
                      foregroundColor: visualStyle.foregroundColor,
                      backgroundColor: colorScheme.surface.withValues(
                        alpha: 0.72,
                      ),
                    ),
                    _RecommendationInformationBadge(
                      icon: Icons.timer_outlined,
                      label: '必要時間 約${best.totalRequiredMinutes}分',
                      foregroundColor: visualStyle.foregroundColor,
                      backgroundColor: colorScheme.surface.withValues(
                        alpha: 0.72,
                      ),
                    ),
                    _RecommendationInformationBadge(
                      icon: Icons.flag_outlined,
                      label: '終了予想 ${_formatTime(best.expectedEndAt)}',
                      foregroundColor: visualStyle.foregroundColor,
                      backgroundColor: colorScheme.surface.withValues(
                        alpha: 0.72,
                      ),
                    ),
                    if (best.remainingMinutesAfterCompletion != null)
                      _RecommendationInformationBadge(
                        icon: Icons.hourglass_bottom,
                        label: '終了後 ${best.remainingMinutesAfterCompletion}分余裕',
                        foregroundColor: visualStyle.foregroundColor,
                        backgroundColor: colorScheme.surface.withValues(
                          alpha: 0.72,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  best.reason,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: visualStyle.foregroundColor,
                    height: 1.45,
                  ),
                ),
                if (best.waitTime.isStale) ...[
                  const SizedBox(height: 9),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_outlined,
                          size: 17,
                          color: colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            '待ち時間情報が30分以上前のものです。'
                            '現地の表示を確認してください。',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      onEditPressed(best.facility);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('待ち時間を確認・更新'),
                  ),
                ),
              ],
            ),
          ),
          if (result.recommendations.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                'ほかの候補',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${result.recommendations.length - 1}件の候補'),
              children: [
                for (
                  var index = 1;
                  index < result.recommendations.length;
                  index++
                )
                  _RecommendationCandidateItem(
                    recommendation: result.recommendations[index],
                    onEditPressed: onEditPressed,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  _RecommendationVisualStyle _recommendationStyle(
    LiveRecommendationLevel level,
  ) {
    return switch (level) {
      LiveRecommendationLevel.highlyRecommended =>
        const _RecommendationVisualStyle(
          icon: Icons.auto_awesome,
          foregroundColor: Color(0xFF176B3A),
          backgroundColor: Color(0xFFE4F6EA),
          borderColor: Color(0xFF8DD2A5),
        ),
      LiveRecommendationLevel.recommended => const _RecommendationVisualStyle(
        icon: Icons.thumb_up_alt_outlined,
        foregroundColor: Color(0xFF2457A6),
        backgroundColor: Color(0xFFEAF2FF),
        borderColor: Color(0xFF9ABBEA),
      ),
      LiveRecommendationLevel.available => const _RecommendationVisualStyle(
        icon: Icons.check_circle_outline,
        foregroundColor: Color(0xFF287A4B),
        backgroundColor: Color(0xFFE8F5ED),
        borderColor: Color(0xFFA5D6B7),
      ),
      LiveRecommendationLevel.caution => const _RecommendationVisualStyle(
        icon: Icons.schedule_outlined,
        foregroundColor: Color(0xFF8A6D00),
        backgroundColor: Color(0xFFFFF8E1),
        borderColor: Color(0xFFFFD54F),
      ),
      LiveRecommendationLevel.unavailable => const _RecommendationVisualStyle(
        icon: Icons.warning_amber_outlined,
        foregroundColor: Color(0xFFC62828),
        backgroundColor: Color(0xFFFFEBEE),
        borderColor: Color(0xFFEF9A9A),
      ),
    };
  }
}

class _RecommendationCandidateItem extends StatelessWidget {
  const _RecommendationCandidateItem({
    required this.recommendation,
    required this.onEditPressed,
  });

  final LiveRecommendation recommendation;
  final ValueChanged<Facility> onEditPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Text(
              '${recommendation.score}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendation.facility.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${recommendation.level.starLabel} '
                  '${recommendation.level.label}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 3),
                Text(
                  recommendation.waitTime.waitMinutes == null
                      ? '待ち時間不明'
                      : '待ち'
                            '${recommendation.waitTime.waitMinutes}分・'
                            '終了予想'
                            '${_formatTime(recommendation.expectedEndAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '待ち時間を更新',
            onPressed: () {
              onEditPressed(recommendation.facility);
            },
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
        ],
      ),
    );
  }
}

class _RecommendationScoreBadge extends StatelessWidget {
  const _RecommendationScoreBadge({required this.recommendation});

  final LiveRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${recommendation.score}点',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RecommendationInformationBadge extends StatelessWidget {
  const _RecommendationInformationBadge({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foregroundColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foregroundColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.facilityCount,
    required this.onRefreshPressed,
  });

  final int facilityCount;
  final Future<void> Function() onRefreshPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.groups_outlined, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'アトラクション待ち時間',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '$facilityCount件',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: '保存済み待ち時間を再読み込み',
          onPressed: () {
            onRefreshPressed();
          },
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.refresh, size: 20),
        ),
      ],
    );
  }
}

class _WaitTimeListItem extends StatelessWidget {
  const _WaitTimeListItem({
    required this.entry,
    required this.now,
    required this.onEditPressed,
  });

  final _LiveWaitTimeListEntry entry;
  final DateTime now;
  final VoidCallback onEditPressed;

  @override
  Widget build(BuildContext context) {
    final waitTime = entry.waitTime;

    final colorScheme = Theme.of(context).colorScheme;

    final foregroundColor = _foregroundColor(waitTime);

    final backgroundColor = _backgroundColor(waitTime);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            waitTime.isStale
                ? Icons.warning_amber_outlined
                : Icons.attractions_outlined,
            size: 23,
            color: foregroundColor,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.facility.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  if (entry.preference != null)
                    _InformationBadge(
                      icon: _accessMethodIcon(entry.preference!.accessMethod),
                      label: entry.preference!.accessMethod.liveShortLabel,
                      foregroundColor: const Color(0xFF6750A4),
                      backgroundColor: const Color(0xFFEDE7F6),
                    ),
                  _InformationBadge(
                    icon: _sourceIcon(waitTime),
                    label: _sourceLabel(waitTime),
                    foregroundColor: foregroundColor,
                    backgroundColor: backgroundColor,
                  ),
                ],
              ),
              if (waitTime.updatedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  _updatedLabel(waitTime.updatedAt!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              waitTime.waitMinutes == null ? '--' : '${waitTime.waitMinutes}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '分',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            IconButton(
              tooltip: '待ち時間を編集',
              onPressed: onEditPressed,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 19),
            ),
          ],
        ),
      ],
    );
  }

  String _updatedLabel(DateTime updatedAt) {
    final difference = now.difference(updatedAt);

    if (difference.isNegative || difference.inMinutes < 1) {
      return 'たった今更新';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分前更新';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}時間前更新';
    }

    return '${difference.inDays}日前更新';
  }

  Color _foregroundColor(LiveWaitTimeDisplay waitTime) {
    if (waitTime.isStale) {
      return const Color(0xFFC62828);
    }

    return switch (waitTime.kind) {
      LiveWaitTimeKind.manual => const Color(0xFF287A4B),
      LiveWaitTimeKind.facilityEstimate => const Color(0xFF2457A6),
      LiveWaitTimeKind.passEstimate => const Color(0xFF6750A4),
      LiveWaitTimeKind.unknown => const Color(0xFF616161),
    };
  }

  Color _backgroundColor(LiveWaitTimeDisplay waitTime) {
    if (waitTime.isStale) {
      return const Color(0xFFFFEBEE);
    }

    return switch (waitTime.kind) {
      LiveWaitTimeKind.manual => const Color(0xFFE8F5ED),
      LiveWaitTimeKind.facilityEstimate => const Color(0xFFEAF2FF),
      LiveWaitTimeKind.passEstimate => const Color(0xFFEDE7F6),
      LiveWaitTimeKind.unknown => const Color(0xFFEEEEEE),
    };
  }

  String _sourceLabel(LiveWaitTimeDisplay waitTime) {
    if (waitTime.isStale) {
      return '要更新';
    }

    return waitTime.label;
  }

  IconData _sourceIcon(LiveWaitTimeDisplay waitTime) {
    if (waitTime.isStale) {
      return Icons.warning_amber_outlined;
    }

    return switch (waitTime.kind) {
      LiveWaitTimeKind.manual => Icons.edit_outlined,
      LiveWaitTimeKind.facilityEstimate => Icons.analytics_outlined,
      LiveWaitTimeKind.passEstimate => Icons.confirmation_number_outlined,
      LiveWaitTimeKind.unknown => Icons.help_outline,
    };
  }
}

class _InformationBadge extends StatelessWidget {
  const _InformationBadge({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foregroundColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveWaitTimeListEntry {
  const _LiveWaitTimeListEntry({
    required this.facility,
    required this.preference,
    required this.waitTime,
  });

  final Facility facility;
  final PlanPreference? preference;
  final LiveWaitTimeDisplay waitTime;
}

class _RecommendationVisualStyle {
  const _RecommendationVisualStyle({
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
}

class _ApproachVisualStyle {
  const _ApproachVisualStyle({
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.iconBackgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color iconBackgroundColor;
  final Color borderColor;
}

IconData _accessMethodIcon(FacilityAccessMethod method) {
  return switch (method) {
    FacilityAccessMethod.standby => Icons.groups_outlined,
    FacilityAccessMethod.dpa => Icons.bolt,
    FacilityAccessMethod.priorityPass => Icons.confirmation_number_outlined,
    FacilityAccessMethod.standbyPass => Icons.airplane_ticket_outlined,
    FacilityAccessMethod.entryRequest => Icons.how_to_reg_outlined,
    FacilityAccessMethod.reservation => Icons.event_available_outlined,
    FacilityAccessMethod.freeSeating => Icons.chair_alt_outlined,
  };
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');

  final minute = value.minute.toString().padLeft(2, '0');

  return '$hour:$minute';
}
