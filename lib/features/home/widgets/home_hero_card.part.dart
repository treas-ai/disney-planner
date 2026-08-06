part of '../home_screen.dart';

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
        schedule != null && schedule!.parkId == settings.parkId;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Ink(
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
        child: Padding(
            padding: const EdgeInsets.all(18),
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
                                'AIと一緒に計画中',
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
                        Icon(
                          scheduleMatchesPark
                              ? Icons.check_circle_outline
                              : Icons.auto_awesome_outlined,
                          color: colorScheme.onPrimaryContainer,
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
                          icon: scheduleMatchesPark
                              ? Icons.check_circle_outline
                              : Icons.auto_awesome_outlined,
                          label: scheduleMatchesPark
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
                      scheduleMatchesPark
                          ? Icons.event_available_outlined
                          : Icons.route_outlined,
                      size: 78,
                      color: colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.24,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
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

