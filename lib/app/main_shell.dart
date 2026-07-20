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
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    PlanEditorScreen(),
    PlanReviewScreen(),
    TodayPlanScreen(),
    SettingsScreen(),
  ];

  final List<String> _titles = const ['ホーム', 'プラン編集', 'プラン確認', '今日の予定', '設定'];

  void _onDestinationSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_currentIndex])),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(AppIcons.home),
            selectedIcon: Icon(AppIcons.homeSelected),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.planEditor),
            selectedIcon: Icon(AppIcons.planEditorSelected),
            label: '編集',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.planReview),
            selectedIcon: Icon(AppIcons.planReviewSelected),
            label: '確認',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.today),
            selectedIcon: Icon(AppIcons.todaySelected),
            label: '予定',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.settings),
            selectedIcon: Icon(AppIcons.settingsSelected),
            label: '設定',
          ),
        ],
      ),
    );
  }
}
