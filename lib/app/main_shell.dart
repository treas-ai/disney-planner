import 'package:flutter/material.dart';

import '../core/theme/app_icons.dart';
import '../features/home/home_screen.dart';
import '../features/plan_editor/plan_editor_screen.dart';
import '../features/plan_review/plan_review_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/today/today_plan_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() {
    return _MainShellState();
  }
}

class _MainShellState extends State<MainShell> {
  static const double _navigationRailBreakpoint = 900;

  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    PlanEditorScreen(),
    PlanReviewScreen(),
    TodayPlanScreen(),
    SettingsScreen(),
  ];

  static const List<_MainDestination> _destinations = [
    _MainDestination(
      title: 'ホーム',
      navigationLabel: 'ホーム',
      subtitle: '現在の設定とプラン作成状況を確認します。',
      icon: AppIcons.home,
      selectedIcon: AppIcons.homeSelected,
    ),
    _MainDestination(
      title: 'プラン編集',
      navigationLabel: '編集',
      subtitle: '行きたい施設と希望条件を設定します。',
      icon: AppIcons.planEditor,
      selectedIcon: AppIcons.planEditorSelected,
    ),
    _MainDestination(
      title: 'プラン確認',
      navigationLabel: 'プラン',
      subtitle: '作成した一日のプランを確認・調整します。',
      icon: AppIcons.planReview,
      selectedIcon: AppIcons.planReviewSelected,
    ),
    _MainDestination(
      title: '当日の予定',
      navigationLabel: '当日',
      subtitle: '採用したプランを当日用の表示で確認します。',
      icon: AppIcons.today,
      selectedIcon: AppIcons.todaySelected,
    ),
    _MainDestination(
      title: '設定',
      navigationLabel: '設定',
      subtitle: '来園条件や利用サービスを設定します。',
      icon: AppIcons.settings,
      selectedIcon: AppIcons.settingsSelected,
    ),
  ];

  void _onDestinationSelected(int index) {
    if (_currentIndex == index) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    final useNavigationRail =
        mediaQuery.size.width >= _navigationRailBreakpoint;

    final destination = _destinations[_currentIndex];

    if (useNavigationRail) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              _DesktopNavigation(
                currentIndex: _currentIndex,
                onDestinationSelected: _onDestinationSelected,
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: Column(
                  children: [
                    _PageHeader(
                      title: destination.title,
                      subtitle: destination.subtitle,
                      icon: destination.selectedIcon,
                      compact: false,
                    ),
                    const Divider(height: 1),
                    Expanded(child: _buildScreenStack()),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _PageHeader(
              title: destination.title,
              subtitle: destination.subtitle,
              icon: destination.selectedIcon,
              compact: true,
            ),
            const Divider(height: 1),
            Expanded(child: _buildScreenStack()),
          ],
        ),
      ),
      bottomNavigationBar: _MobileNavigation(
        currentIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }

  Widget _buildScreenStack() {
    return IndexedStack(index: _currentIndex, children: _screens);
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.compact,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 16 : 24,
          compact ? 9 : 13,
          compact ? 16 : 24,
          compact ? 8 : 12,
        ),
        child: Row(
          children: [
            Container(
              width: compact ? 34 : 40,
              height: compact ? 34 : 40,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(compact ? 10 : 12),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: compact ? 19 : 22,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: compact
                        ? Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          )
                        : Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 210,
      color: colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.auto_awesome,
                    size: 21,
                    color: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Disney Planner',
                    maxLines: 2,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _MainShellState._destinations.length,
              separatorBuilder: (_, _) {
                return const SizedBox(height: 4);
              },
              itemBuilder: (context, index) {
                final destination = _MainShellState._destinations[index];

                final selected = currentIndex == index;

                return _DesktopNavigationItem(
                  destination: destination,
                  selected: selected,
                  onPressed: () {
                    onDestinationSelected(index);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              '施設選択から当日確認まで',
              textAlign: TextAlign.center,
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

class _DesktopNavigationItem extends StatelessWidget {
  const _DesktopNavigationItem({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });

  final _MainDestination destination;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected ? colorScheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 21,
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  destination.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: colorScheme.onPrimaryContainer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        for (final destination in _MainShellState._destinations)
          NavigationDestination(
            tooltip: destination.title,
            icon: Icon(destination.icon, size: 22),
            selectedIcon: Icon(destination.selectedIcon, size: 22),
            label: destination.navigationLabel,
          ),
      ],
    );
  }
}

class _MainDestination {
  const _MainDestination({
    required this.title,
    required this.navigationLabel,
    required this.subtitle,
    required this.icon,
    required this.selectedIcon,
  });

  final String title;
  final String navigationLabel;
  final String subtitle;
  final IconData icon;
  final IconData selectedIcon;
}
