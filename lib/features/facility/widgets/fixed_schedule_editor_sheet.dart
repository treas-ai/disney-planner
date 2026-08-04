import 'package:flutter/material.dart';

import '../../../app/state/app_state.dart';
import '../../../data/local/local_performance_schedule_repository.dart';
import '../../../domain/entities/facility.dart';
import '../../../domain/entities/performance_time_option.dart';
import '../../../domain/entities/plan_preference.dart';
import '../../../domain/enums/facility_access_method.dart';
import '../../../domain/enums/facility_category.dart';
import '../../../domain/enums/fixed_time_status.dart';
import '../../../domain/enums/lottery_fallback_action.dart';

Future<bool> showFixedScheduleEditorSheet({
  required BuildContext context,
  required AppState appState,
  required Facility facility,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) =>
        _FixedScheduleEditorSheet(appState: appState, facility: facility),
  );
  return result == true;
}

class _FixedScheduleEditorSheet extends StatefulWidget {
  const _FixedScheduleEditorSheet({
    required this.appState,
    required this.facility,
  });
  final AppState appState;
  final Facility facility;

  @override
  State<_FixedScheduleEditorSheet> createState() =>
      _FixedScheduleEditorSheetState();
}

class _FixedScheduleEditorSheetState extends State<_FixedScheduleEditorSheet> {
  final LocalPerformanceScheduleRepository _repository =
      LocalPerformanceScheduleRepository();
  List<PerformanceTimeOption> _performanceOptions = const [];
  bool _loading = false;
  String? _loadError;

  PlanPreference get preference =>
      widget.appState.getPreference(widget.facility.id) ??
      PlanPreference.initial(facilityId: widget.facility.id);

  bool get _isPerformance =>
      widget.facility.category == FacilityCategory.show ||
      widget.facility.category == FacilityCategory.parade;

  bool get _usesAccessTime => switch (preference.accessMethod) {
    FacilityAccessMethod.dpa ||
    FacilityAccessMethod.priorityPass ||
    FacilityAccessMethod.standbyPass ||
    FacilityAccessMethod.entryRequest => true,
    _ => false,
  };

  bool get _usesReservationTime =>
      widget.facility.isRestaurant ||
      preference.accessMethod == FacilityAccessMethod.reservation;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_refresh);
    if (_isPerformance) {
      _loadPerformanceOptions();
    }
  }

  @override
  void dispose() {
    widget.appState.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadPerformanceOptions() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final options = await _repository.findOptions(
        parkId: widget.facility.parkId,
        facilityId: widget.facility.id,
        date: DateTime.now(),
      );
      if (!mounted) {
        return;
      }
      setState(() => _performanceOptions = options);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loadError = '公演マスターを読み込めませんでした。');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _statusLabel(FixedTimeStatus status) {
    if (preference.accessMethod == FacilityAccessMethod.entryRequest) {
      return switch (status) {
        FixedTimeStatus.none => '外れ・利用なし',
        FixedTimeStatus.planned => '抽選予定',
        FixedTimeStatus.confirmed => '当選',
      };
    }
    if (_usesReservationTime) {
      return switch (status) {
        FixedTimeStatus.none => '予約なし',
        FixedTimeStatus.planned => '予約予定',
        FixedTimeStatus.confirmed => '事前予約済み',
      };
    }
    return switch (status) {
      FixedTimeStatus.none => '取得なし',
      FixedTimeStatus.planned => '取得予定',
      FixedTimeStatus.confirmed => '取得済み',
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = preference;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.facility.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<FixedTimeStatus>(
                initialValue: p.fixedTimeStatus,
                decoration: const InputDecoration(
                  labelText: '取得・予約状態',
                  border: OutlineInputBorder(),
                ),
                items: FixedTimeStatus.values
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(_statusLabel(v)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    widget.appState.updatePreferenceFixedTimeStatus(
                      facilityId: widget.facility.id,
                      status: value,
                    );
                  }
                },
              ),
              if (_isPerformance) ...[
                const SizedBox(height: 14),
                if (_loading) const LinearProgressIndicator(),
                if (_loadError != null) Text(_loadError!),
                if (!_loading && _performanceOptions.isEmpty)
                  const Text('本日の公式公演時刻は未登録です。仮の時刻は作成しません。'),
                if (_performanceOptions.isNotEmpty)
                  DropdownButtonFormField<int>(
                    initialValue: p.selectedPerformanceIndex,
                    decoration: const InputDecoration(
                      labelText: '公式公演時刻',
                      border: OutlineInputBorder(),
                    ),
                    items: _performanceOptions
                        .map(
                          (o) => DropdownMenuItem(
                            value: o.performanceIndex,
                            child: Text(o.displayLabel),
                          ),
                        )
                        .toList(),
                    onChanged: (index) {
                      final matches = _performanceOptions.where(
                        (o) => o.performanceIndex == index,
                      );
                      final selected = matches.isEmpty ? null : matches.first;
                      widget.appState.updatePreferenceSelectedPerformance(
                        facilityId: widget.facility.id,
                        performanceIndex: selected?.performanceIndex,
                        startTime: selected?.startTime ?? '',
                      );
                    },
                  ),
              ],
              if (!_isPerformance &&
                  p.fixedTimeStatus == FixedTimeStatus.confirmed &&
                  (_usesAccessTime || _usesReservationTime)) ...[
                const SizedBox(height: 14),
                _TenMinuteTimeField(
                  label: _usesReservationTime
                      ? (widget.facility.supportsMobileOrder
                            ? '予約・受取時刻'
                            : '予約時刻')
                      : '利用時刻',
                  value: _usesReservationTime
                      ? p.reservationTime
                      : p.scheduledAccessTime,
                  onChanged: (value) {
                    if (_usesReservationTime) {
                      widget.appState.updatePreferenceReservationTime(
                        facilityId: widget.facility.id,
                        value: value,
                      );
                    } else {
                      widget.appState.updatePreferenceScheduledAccessTime(
                        facilityId: widget.facility.id,
                        value: value,
                      );
                    }
                  },
                ),
              ],
              if (p.accessMethod == FacilityAccessMethod.entryRequest) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<LotteryFallbackAction>(
                  initialValue: p.lotteryFallbackAction,
                  decoration: const InputDecoration(
                    labelText: '外れた場合',
                    border: OutlineInputBorder(),
                  ),
                  items: LotteryFallbackAction.values
                      .map(
                        (v) => DropdownMenuItem(value: v, child: Text(v.label)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      widget.appState.updatePreferenceLotteryFallbackAction(
                        facilityId: widget.facility.id,
                        action: value,
                      );
                    }
                  },
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.check),
                  label: const Text('変更を反映'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TenMinuteTimeField extends StatelessWidget {
  const _TenMinuteTimeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final values = <String>[
      for (var hour = 6; hour <= 23; hour++)
        for (var minute = 0; minute < 60; minute += 10)
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
    ];
    final selected = values.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: selected,
      decoration: InputDecoration(
        labelText: label,
        helperText: '10分刻みで選択します。',
        border: const OutlineInputBorder(),
      ),
      items: values
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: (v) => onChanged(v ?? ''),
    );
  }
}
