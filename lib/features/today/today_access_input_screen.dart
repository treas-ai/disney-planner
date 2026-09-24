import 'package:flutter/material.dart';

import '../../app/state/app_state.dart';
import '../../app/state/app_state_scope.dart';
import '../../app/dependency/service_locator.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/scroll_time_picker.dart';
import '../../data/local/local_performance_schedule_repository.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/performance_time_option.dart';
import '../../domain/entities/today_access_result.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/enums/fixed_time_status.dart';
import '../../domain/enums/schedule_item_type.dart';
import '../../domain/enums/today_access_kind.dart';
import '../../domain/enums/today_access_status.dart';
import '../../domain/services/dpa_timing_advisor.dart';

class TodayAccessInputScreen extends StatefulWidget {
  const TodayAccessInputScreen({
    super.key,
    this.onContinueToToday,
  });

  final VoidCallback? onContinueToToday;

  @override
  State<TodayAccessInputScreen> createState() => _TodayAccessInputScreenState();
}

class _TodayAccessInputScreenState extends State<TodayAccessInputScreen> {
  List<Facility> _parkFacilities = const [];
  Set<String> _scheduledEntertainmentIds = const <String>{};
  String? _loadedOperationKey;
  bool _hasChanges = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final trip = AppStateScope.of(context).tripSettings;
    final parkId = trip.parkId;
    final visitDate = trip.visitDate ?? DateTime.now();
    final operationKey =
        '$parkId:${visitDate.year}-${visitDate.month}-${visitDate.day}';
    if (_loadedOperationKey == operationKey) return;
    _loadedOperationKey = operationKey;
    _loadOperatingCandidates(parkId, visitDate, operationKey);
  }

  Future<void> _loadOperatingCandidates(
    String parkId,
    DateTime visitDate,
    String operationKey,
  ) async {
    final facilities = await ServiceLocator.facilityRepository
        .getFacilitiesByParkId(parkId);
    final performanceOptions = await LocalPerformanceScheduleRepository()
        .findParkOptions(parkId: parkId, date: visitDate);
    if (!mounted || _loadedOperationKey != operationKey) return;

    // 施設マスタの開催期間・公式休止期間を最優先し、さらにショー／
    // パレードは来園日の公式公演時刻が登録されているものだけを候補にする。
    // 「マスタに存在する」だけでは当日利用可能とはみなさない。
    setState(() {
      _parkFacilities = facilities
          .where((facility) => facility.canAddToPlanAt(visitDate))
          .toList(growable: false);
      _scheduledEntertainmentIds = performanceOptions
          .map((option) => option.facilityId)
          .toSet();
    });
  }

  Future<void> _edit(
    AppState appState,
    Facility facility,
    TodayAccessKind kind,
  ) async {
    final current = appState.todayAccessResultFor(facility.id, kind);
    final result = await showModalBottomSheet<_EditorResult>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => _TodayAccessEditorSheet(
        facility: facility,
        kind: kind,
        current: current,
        timingAdvice: _buildTimingAdvice(appState, facility, kind),
        visitDate: appState.tripSettings.visitDate ?? DateTime.now(),
      ),
    );
    if (result == null || !mounted) return;
    if (result.remove) {
      appState.removeTodayAccessResult(facility.id, kind);
      _hasChanges = true;
    } else if (result.value != null) {
      appState.upsertTodayAccessResult(result.value!);
      _hasChanges = true;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final attractionCandidates = <_AccessCandidate>[];
    final showCandidates = <_AccessCandidate>[];
    final mobileOrderCandidates = <_AccessCandidate>[];

    // DPA は当日の判断で予定外に取得することがあるため、事前プランに関係なく
    // パーク内の対象施設をすべて候補にする。
    for (final facility in _parkFacilities) {
      if (!facility.supportsDpa) continue;
      if (facility.category == FacilityCategory.attraction) {
        attractionCandidates.add(
          _AccessCandidate(facility, TodayAccessKind.attractionDpa),
        );
      } else if ((facility.category == FacilityCategory.show ||
              facility.category == FacilityCategory.parade) &&
          _scheduledEntertainmentIds.contains(facility.id)) {
        showCandidates.add(
          _AccessCandidate(facility, TodayAccessKind.showDpa),
        );
      }
    }

    // ショー抽選も「予定外だが、とりあえず抽選する」運用に対応する。
    for (final facility in _parkFacilities) {
      if (facility.category == FacilityCategory.show &&
          facility.requiresEntryRequest &&
          _scheduledEntertainmentIds.contains(facility.id)) {
        showCandidates.add(
          _AccessCandidate(facility, TodayAccessKind.entryRequest),
        );
      }
    }

    // MO は初心者向けの分かりやすさを優先し、現段階では事前に選んだ店舗だけ。
    for (final facility in appState.selectedFacilitiesForPark(
      appState.tripSettings.parkId,
    )) {
      final visitDate = appState.tripSettings.visitDate ?? DateTime.now();
      if (facility.supportsMobileOrder && facility.canAddToPlanAt(visitDate)) {
        mobileOrderCandidates.add(
          _AccessCandidate(facility, TodayAccessKind.mobileOrder),
        );
      }
    }

    void sortCandidates(List<_AccessCandidate> values) {
      values.sort((a, b) {
        final byName = a.facility.name.compareTo(b.facility.name);
        if (byName != 0) return byName;
        return a.kind.index.compareTo(b.kind.index);
      });
    }

    sortCandidates(attractionCandidates);
    sortCandidates(showCandidates);
    sortCandidates(mobileOrderCandidates);
    final hasCandidates = attractionCandidates.isNotEmpty ||
        showCandidates.isNotEmpty ||
        mobileOrderCandidates.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('当日の取得状況を入力')),
      body: !hasCandidates
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('現在のパークには、入力対象のDPA・ショー抽選・MOがありません。'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '予定ではなく、当日に実際に取れた結果を入力します',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '来園日の公式運営状況に合う対象だけを表示します。DPAとショー抽選は事前プラン外も対象、MOは事前に選んだ営業対象店舗だけです。未入力は「取得していない」扱いなので、実際に取得・当選・落選などがあった項目だけ入力すればOKです。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (attractionCandidates.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _AccessSection(
                    title: 'アトラクション',
                    icon: Icons.attractions_outlined,
                    candidates: attractionCandidates,
                    appState: appState,
                    onEdit: _edit,
                  ),
                ],
                if (showCandidates.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _AccessSection(
                    title: 'ショー・パレード',
                    icon: Icons.theater_comedy_outlined,
                    candidates: showCandidates,
                    appState: appState,
                    onEdit: _edit,
                  ),
                ],
                if (mobileOrderCandidates.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _AccessSection(
                    title: 'モバイルオーダー',
                    icon: Icons.restaurant_outlined,
                    candidates: mobileOrderCandidates,
                    appState: appState,
                    onEdit: _edit,
                  ),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop(_hasChanges);
            widget.onContinueToToday?.call();
          },
          icon: const Icon(Icons.event_available_outlined),
          label: const Text('入力を終えて当日ガイドへ'),
        ),
      ),
    );
  }
}

typedef _EditAccessCandidate = Future<void> Function(
  AppState appState,
  Facility facility,
  TodayAccessKind kind,
);

class _AccessSection extends StatelessWidget {
  const _AccessSection({
    required this.title,
    required this.icon,
    required this.candidates,
    required this.appState,
    required this.onEdit,
  });

  final String title;
  final IconData icon;
  final List<_AccessCandidate> candidates;
  final AppState appState;
  final _EditAccessCandidate onEdit;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<_AccessCandidate>>{};
    for (final candidate in candidates) {
      grouped.putIfAbsent(candidate.facility.id, () => []).add(candidate);
    }
    final groups = grouped.values.toList()
      ..sort((a, b) => a.first.facility.name.compareTo(b.first.facility.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < groups.length; i++) ...[
          _FacilityAccessCard(
            candidates: groups[i],
            appState: appState,
            onEdit: onEdit,
          ),
          if (i != groups.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _AccessCandidate {
  const _AccessCandidate(this.facility, this.kind);
  final Facility facility;
  final TodayAccessKind kind;
}

class _FacilityAccessCard extends StatelessWidget {
  const _FacilityAccessCard({
    required this.candidates,
    required this.appState,
    required this.onEdit,
  });

  final List<_AccessCandidate> candidates;
  final AppState appState;
  final _EditAccessCandidate onEdit;

  @override
  Widget build(BuildContext context) {
    final facility = candidates.first.facility;
    final scheme = Theme.of(context).colorScheme;
    final ordered = [...candidates]
      ..sort((a, b) => a.kind.index.compareTo(b.kind.index));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.confirmation_number_outlined, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  facility.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < ordered.length; i++) ...[
            _AccessKindRow(
              candidate: ordered[i],
              result: appState.todayAccessResultFor(
                facility.id,
                ordered[i].kind,
              ),
              timingAdvice: _buildTimingAdvice(
                appState,
                facility,
                ordered[i].kind,
              ),
              onTap: () => onEdit(appState, facility, ordered[i].kind),
            ),
            if (i != ordered.length - 1) const Divider(height: 14),
          ],
        ],
      ),
    );
  }
}

class _AccessKindRow extends StatelessWidget {
  const _AccessKindRow({
    required this.candidate,
    required this.result,
    required this.timingAdvice,
    required this.onTap,
  });

  final _AccessCandidate candidate;
  final TodayAccessResult? result;
  final _TimingAdvice timingAdvice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = result;
    // 全施設を入力させない。未入力は「取得していない」を既定表示とし、
    // 実際に取得・当選・落選などがあった項目だけユーザーが更新する。
    final summary = value == null
        ? '取得していない'
        : [
            value.status.label,
            if (value.hasTime) value.time,
            if (value.note.trim().isNotEmpty) value.note.trim(),
          ].join(' / ');
    final hasAvoid = candidate.kind == TodayAccessKind.attractionDpa &&
        timingAdvice.attractionDpaRanges().any(
          (range) => range.rating == DpaTimingRating.avoid,
        );

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${candidate.kind.label}：$summary',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: value == null
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                          fontWeight: value == null
                              ? FontWeight.w500
                              : FontWeight.w700,
                        ),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            if (timingAdvice.hasCaution) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    hasAvoid ? Icons.block_outlined : Icons.info_outline,
                    size: 15,
                    color: hasAvoid ? scheme.error : scheme.tertiary,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      candidate.kind == TodayAccessKind.attractionDpa
                          ? (hasAvoid
                              ? '避ける時間あり（タップして確認）'
                              : '時間に注意あり（タップして確認）')
                          : '時間競合に注意（タップして確認）',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: hasAvoid
                                ? scheme.error
                                : scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EditorResult {
  const _EditorResult.value(this.value) : remove = false;
  const _EditorResult.remove() : value = null, remove = true;
  final TodayAccessResult? value;
  final bool remove;
}

class _TodayAccessEditorSheet extends StatefulWidget {
  const _TodayAccessEditorSheet({
    required this.facility,
    required this.kind,
    required this.current,
    required this.timingAdvice,
    required this.visitDate,
  });

  final Facility facility;
  final TodayAccessKind kind;
  final TodayAccessResult? current;
  final _TimingAdvice timingAdvice;
  final DateTime visitDate;

  @override
  State<_TodayAccessEditorSheet> createState() => _TodayAccessEditorSheetState();
}

class _TodayAccessEditorSheetState extends State<_TodayAccessEditorSheet> {
  late TodayAccessStatus _status;
  TimeOfDay? _time;
  late final TextEditingController _noteController;
  final LocalPerformanceScheduleRepository _performanceRepository =
      LocalPerformanceScheduleRepository();
  List<PerformanceTimeOption> _performanceOptions = const [];
  bool _loadingPerformanceOptions = false;
  String? _performanceLoadError;

  @override
  void initState() {
    super.initState();
    _status = widget.current?.status ?? _defaultStatus(widget.kind);
    _time = _parseTime(widget.current?.time ?? '');
    _noteController = TextEditingController(text: widget.current?.note ?? '');
    if (widget.kind == TodayAccessKind.showDpa ||
        widget.kind == TodayAccessKind.entryRequest) {
      _loadPerformanceOptions();
    }
  }

  Future<void> _loadPerformanceOptions() async {
    setState(() {
      _loadingPerformanceOptions = true;
      _performanceLoadError = null;
    });
    try {
      final options = await _performanceRepository.findOptions(
        parkId: widget.facility.parkId,
        facilityId: widget.facility.id,
        date: widget.visitDate,
      );
      if (!mounted) return;
      setState(() => _performanceOptions = options);
    } catch (_) {
      if (!mounted) return;
      setState(() => _performanceLoadError = '公演時刻を読み込めませんでした。');
    } finally {
      if (mounted) setState(() => _loadingPerformanceOptions = false);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool get _needsTime =>
      _status == TodayAccessStatus.acquired || _status == TodayAccessStatus.won;

  Future<void> _pickTime() async {
    final initial = _time ?? const TimeOfDay(hour: 12, minute: 0);
    final picked = await showScrollTimePicker(
      context: context,
      initialTime: initial,
      minTime: const TimeOfDay(hour: 9, minute: 0),
      maxTime: const TimeOfDay(hour: 21, minute: 0),
      minuteStep: 10,
      title: switch (widget.kind) {
        TodayAccessKind.attractionDpa => 'DPA利用開始時刻',
        TodayAccessKind.standbyPass => 'スタンバイパス利用時刻',
        TodayAccessKind.mobileOrder => 'モバイルオーダー受取時刻',
        _ => '取得した時刻',
      },
      helperText: '9:00〜21:00を10分刻みでスクロールして選択します。',
    );
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _statusesFor(widget.kind);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.facility.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(widget.kind.label),
            if (widget.timingAdvice.hasCaution) ...[
              const SizedBox(height: 10),
              _TimingAdvicePanel(
                advice: widget.timingAdvice,
                selectedTime: _time,
                kind: widget.kind,
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<TodayAccessStatus>(
              initialValue: statuses.contains(_status) ? _status : statuses.first,
              decoration: const InputDecoration(labelText: '結果'),
              items: [
                for (final value in statuses)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            if (_needsTime &&
                (widget.kind == TodayAccessKind.showDpa ||
                    widget.kind == TodayAccessKind.entryRequest)) ...[
              const SizedBox(height: 12),
              if (_loadingPerformanceOptions) const LinearProgressIndicator(),
              if (_performanceLoadError != null)
                Text(
                  _performanceLoadError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (!_loadingPerformanceOptions &&
                  _performanceLoadError == null &&
                  _performanceOptions.isEmpty)
                const Text(
                  'この来園日の公演時刻が登録されていません。仮の時刻は作成しません。公式アプリの公演時刻を確認してください。',
                ),
              if (_performanceOptions.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _time != null &&
                          _performanceOptions.any(
                            (option) => option.startTime == _formatTime(_time!),
                          )
                      ? _formatTime(_time!)
                      : null,
                  decoration: InputDecoration(
                    labelText: '取得した公演回',
                    helperText: widget.kind == TodayAccessKind.showDpa
                        ? 'ショー・パレードDPAは当日の公演回から選択します'
                        : 'エントリー受付は当日の公演回から選択します',
                  ),
                  items: [
                    for (final option in _performanceOptions)
                      DropdownMenuItem(
                        value: option.startTime,
                        child: Text(option.displayLabel),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _time = _parseTime(value));
                  },
                ),
            ] else if (_needsTime) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    _time == null
                        ? '実際に取れた時間を選択'
                        : '時間 ${_formatTime(_time!)}',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'メモ（任意）',
                hintText: '予定と違った点など',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.current != null)
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(
                      const _EditorResult.remove(),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('入力を削除'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _needsTime &&
                          (_time == null ||
                              ((widget.kind == TodayAccessKind.showDpa ||
                                      widget.kind == TodayAccessKind.entryRequest) &&
                                  _performanceOptions.isEmpty))
                      ? null
                      : () {
                          Navigator.of(context).pop(
                            _EditorResult.value(
                              TodayAccessResult(
                                facilityId: widget.facility.id,
                                kind: widget.kind,
                                status: _status,
                                time: _time == null ? '' : _formatTime(_time!),
                                note: _noteController.text.trim(),
                                updatedAt: DateTime.now(),
                              ),
                            ),
                          );
                        },
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class _AvoidWindow {
  const _AvoidWindow({
    required this.startMinutes,
    required this.endMinutes,
    required this.reason,
  });

  final int startMinutes;
  final int endMinutes;
  final String reason;

  bool contains(TimeOfDay value) {
    final minutes = value.hour * 60 + value.minute;
    return startMinutes <= minutes && minutes <= endMinutes;
  }

  String get label => '${_clock(startMinutes)}〜${_clock(endMinutes)}';
}

class _TimingAdvice {
  const _TimingAdvice(
    this.windows, {
    required this.exitMinutes,
    required this.targetUseMinutes,
  });
  final List<_AvoidWindow> windows;
  final int exitMinutes;
  final int targetUseMinutes;

  bool get hasCaution =>
      windows.isNotEmpty ||
      rateAttractionDpaStart(exitMinutes) != DpaTimingRating.good;

  _AvoidWindow? conflictAt(TimeOfDay? time) {
    if (time == null) return null;
    for (final window in windows) {
      if (window.contains(time)) return window;
    }
    return null;
  }

  DpaTimingRating rateAttractionDpaStart(int startMinutes) {
    // 退園直前を「固定予定が無いから安全」とは扱わない。
    // 利用開始直後に入ったとしても体験終了が退園予定を越える場合は避ける。
    final finishIfUsedImmediately = startMinutes + targetUseMinutes;
    if (finishIfUsedImmediately > exitMinutes) {
      return DpaTimingRating.avoid;
    }
    if (exitMinutes - finishIfUsedImmediately < 20) {
      return DpaTimingRating.caution;
    }
    return const DpaTimingAdvisor().rateStart(
      startMinutes: startMinutes,
      blockedWindows: [
        for (final window in windows)
          DpaBlockedWindow(
            startMinutes: window.startMinutes,
            endMinutes: window.endMinutes,
          ),
      ],
    );
  }

  List<DpaTimingRange> attractionDpaRanges({
    int startMinutes = 8 * 60,
    int? endMinutes,
  }) {
    final lastMinute = endMinutes ?? exitMinutes;
    final ranges = <DpaTimingRange>[];
    DpaTimingRating? current;
    int? rangeStart;
    for (var minute = startMinutes; minute <= lastMinute; minute += 10) {
      final rating = rateAttractionDpaStart(minute);
      if (current == null) {
        current = rating;
        rangeStart = minute;
        continue;
      }
      if (rating != current) {
        ranges.add(DpaTimingRange(
          startMinutes: rangeStart!,
          endMinutes: minute - 10,
          rating: current,
        ));
        current = rating;
        rangeStart = minute;
      }
    }
    if (current != null && rangeStart != null) {
      ranges.add(DpaTimingRange(
        startMinutes: rangeStart,
        endMinutes: lastMinute,
        rating: current,
      ));
    }
    return List<DpaTimingRange>.unmodifiable(ranges);
  }

  String reasonsForRanges(List<DpaTimingRange> ranges) {
    final reasons = <String>{};
    for (final range in ranges) {
      // DPAは開始時刻から約1時間の利用枠があるため、
      // その枠に影響する固定予定の理由を集める。
      final influencedEnd = range.endMinutes + 50;
      for (final window in windows) {
        final overlaps =
            window.endMinutes >= range.startMinutes &&
            window.startMinutes <= influencedEnd;
        if (overlaps) reasons.add(window.reason);
      }
    }
    if (ranges.any((range) => range.startMinutes + targetUseMinutes > exitMinutes)) {
      reasons.add('退園予定 ${_clock(exitMinutes)}');
    }
    return reasons.join(' / ');
  }
}

class _TimingAdvicePanel extends StatelessWidget {
  const _TimingAdvicePanel({
    required this.advice,
    required this.selectedTime,
    required this.kind,
  });

  final _TimingAdvice advice;
  final TimeOfDay? selectedTime;
  final TodayAccessKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (kind == TodayAccessKind.attractionDpa) {
      final selectedMinutes = selectedTime == null
          ? null
          : selectedTime!.hour * 60 + selectedTime!.minute;
      final selectedRating = selectedMinutes == null
          ? null
          : advice.rateAttractionDpaStart(selectedMinutes);
      final avoidRanges = advice
          .attractionDpaRanges()
          .where((range) => range.rating == DpaTimingRating.avoid)
          .toList();

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DPA利用開始時刻の目安',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              avoidRanges.isEmpty
                  ? '大きな固定予定との競合はありません。実際に表示された利用開始時刻を選ぶと、退園時刻も含めて個別に確認できます。'
                  : '下の時間帯は避けるのがおすすめです。それ以外も自動的に安全という意味ではなく、実際の利用開始時刻を選んで個別に確認してください。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (avoidRanges.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (var i = 0; i < avoidRanges.length; i++) ...[
                _DpaAvoidCard(
                  range: avoidRanges[i],
                  reason: advice.reasonsForRanges([avoidRanges[i]]),
                ),
                if (i != avoidRanges.length - 1) const SizedBox(height: 6),
              ],
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 17,
                    color: scheme.tertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '避ける時間帯の前後は注意。移動や次の固定予定への余裕が少なくなる場合があります。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 17,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '赤い時間帯以外も自動的に「取得OK」にはしません。特に退園前は、体験終了まで間に合うかを選択時刻ごとに判定します。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ],
            if (selectedRating != null) ...[
              const SizedBox(height: 10),
              _SelectedDpaRatingBanner(rating: selectedRating),
            ],
            const SizedBox(height: 6),
            Text(
              'DPAの約1時間の利用枠を10分刻みで確認し、固定公演・予約済み時刻・取得済み枠との両立を判定したPlanner上の目安です。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    final conflict = advice.conflictAt(selectedTime);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: conflict == null
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.65)
            : scheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conflict == null ? '固定予定との時間競合を確認します' : '選択中の時刻は競合しやすいです',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            conflict == null
                ? '固定公演、予約済み時刻、取得・当選済み時間だけを競合判定に使います。予約のない食事や通常施設は必要に応じて再配置します。'
                : '「${conflict.reason}」は動かせない予定のため、この時刻は避けるのがおすすめです。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _DpaAvoidCard extends StatelessWidget {
  const _DpaAvoidCard({
    required this.range,
    required this.reason,
  });

  final DpaTimingRange range;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.block_outlined, size: 18, color: scheme.error),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '避ける  ${_dpaRangeText(range)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.error,
                      ),
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '「$reason」と両立しにくくなります。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedDpaRatingBanner extends StatelessWidget {
  const _SelectedDpaRatingBanner({required this.rating});

  final DpaTimingRating rating;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (rating) {
      DpaTimingRating.good => Icons.check_circle_outline,
      DpaTimingRating.caution => Icons.warning_amber_rounded,
      DpaTimingRating.avoid => Icons.block_outlined,
    };
    final title = switch (rating) {
      DpaTimingRating.good => '選択した時刻：取得OK',
      DpaTimingRating.caution => '選択した時刻：注意',
      DpaTimingRating.avoid => '選択した時刻：避ける',
    };
    final detail = switch (rating) {
      DpaTimingRating.good => '固定予定との両立に十分な余裕があります。',
      DpaTimingRating.caution => '利用はできますが、移動や固定予定への余裕が少なくなります。',
      DpaTimingRating.avoid => '固定予定との両立が難しいため、別の開始時刻がおすすめです。',
    };
    final foreground = switch (rating) {
      DpaTimingRating.good => scheme.primary,
      DpaTimingRating.caution => scheme.tertiary,
      DpaTimingRating.avoid => scheme.error,
    };
    final background = switch (rating) {
      DpaTimingRating.good => scheme.primaryContainer.withValues(alpha: 0.55),
      DpaTimingRating.caution => scheme.tertiaryContainer.withValues(alpha: 0.55),
      DpaTimingRating.avoid => scheme.errorContainer.withValues(alpha: 0.65),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: foreground,
                      ),
                ),
                const SizedBox(height: 2),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _dpaRangeText(DpaTimingRange range) {
  return range.endMinutes > range.startMinutes
      ? '${_clock(range.startMinutes)}〜${_clock(range.endMinutes)}'
      : _clock(range.startMinutes);
}

_TimingAdvice _buildTimingAdvice(
  AppState appState,
  Facility target,
  TodayAccessKind kind,
) {
  final targetUseMinutes = switch (kind) {
    TodayAccessKind.attractionDpa => target.durationMinutes + 10,
    TodayAccessKind.standbyPass => target.durationMinutes + 10,
    TodayAccessKind.showDpa => target.durationMinutes,
    TodayAccessKind.entryRequest => target.durationMinutes,
    TodayAccessKind.mobileOrder => target.durationMinutes,
    TodayAccessKind.priorityPass => target.durationMinutes + 10,
  };
  final exitMinutes = appState.tripSettings.exitTimeHour * 60 +
      appState.tripSettings.exitTimeMinute;
  final schedule = appState.daySchedule;
  if (schedule == null) {
    return _TimingAdvice(
      const <_AvoidWindow>[],
      exitMinutes: exitMinutes,
      targetUseMinutes: targetUseMinutes,
    );
  }

  final facilityById = {
    for (final facility in appState.selectedFacilities) facility.id: facility,
  };
  final preferenceById = {
    for (final preference in appState.planPreferences) preference.facilityId: preference,
  };
  final confirmedTodayIds = appState.todayAccessResults
      .where((result) => result.fixesTime)
      .map((result) => result.facilityId)
      .toSet();

  const arrivalMarginMinutes = 15;
  final raw = <_AvoidWindow>[];

  for (final item in schedule.items) {
    if (item.facilityId == target.id) continue;
    if (item.type == ScheduleItemType.entry ||
        item.type == ScheduleItemType.exit ||
        item.type == ScheduleItemType.breakTime) {
      continue;
    }
    final facility = item.facilityId == null ? null : facilityById[item.facilityId];
    final preference = item.facilityId == null ? null : preferenceById[item.facilityId];
    // DPA取得判断の警告原因は「本当に動かせない予定」だけにする。
    // 予約のない朝食・昼食・夕食、通常アトラクション、ショップ、休憩は
    // DPAに合わせて再配置できるため、ここではブロックしない。
    final fixed =
        facility?.category == FacilityCategory.show ||
        facility?.category == FacilityCategory.parade ||
        preference?.fixedTimeStatus == FixedTimeStatus.confirmed ||
        (item.facilityId != null && confirmedTodayIds.contains(item.facilityId));
    if (!fixed) continue;

    final anchorStart = item.startHour * 60 + item.startMinute;
    final anchorEnd = item.endHour * 60 + item.endMinute;
    final start = (anchorStart - targetUseMinutes - arrivalMarginMinutes).clamp(0, 24 * 60 - 1).toInt();
    final end = (anchorEnd + arrivalMarginMinutes).clamp(0, 24 * 60 - 1).toInt();
    raw.add(_AvoidWindow(
      startMinutes: start,
      endMinutes: end,
      reason: item.title,
    ));
  }

  raw.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  final merged = <_AvoidWindow>[];
  for (final window in raw) {
    if (merged.isEmpty || window.startMinutes > merged.last.endMinutes + 5) {
      merged.add(window);
      continue;
    }
    final previous = merged.removeLast();
    final reasons = <String>{...previous.reason.split(' / '), window.reason};
    merged.add(
      _AvoidWindow(
        startMinutes: previous.startMinutes,
        endMinutes: window.endMinutes > previous.endMinutes
            ? window.endMinutes
            : previous.endMinutes,
        reason: reasons.join(' / '),
      ),
    );
  }
  return _TimingAdvice(
    List<_AvoidWindow>.unmodifiable(merged),
    exitMinutes: exitMinutes,
    targetUseMinutes: targetUseMinutes,
  );
}

String _clock(int minutes) {
  final normalized = minutes.clamp(0, 24 * 60 - 1).toInt();
  final hour = normalized ~/ 60;
  final minute = normalized % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

TodayAccessStatus _defaultStatus(TodayAccessKind kind) {
  return kind == TodayAccessKind.entryRequest
      ? TodayAccessStatus.won
      : TodayAccessStatus.acquired;
}

List<TodayAccessStatus> _statusesFor(TodayAccessKind kind) {
  if (kind == TodayAccessKind.entryRequest) {
    return const [
      TodayAccessStatus.won,
      TodayAccessStatus.lost,
      TodayAccessStatus.skipped,
    ];
  }
  return const [
    TodayAccessStatus.acquired,
    TodayAccessStatus.unavailable,
    TodayAccessStatus.skipped,
  ];
}

TimeOfDay? _parseTime(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null || hour > 23 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _formatTime(TimeOfDay value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
