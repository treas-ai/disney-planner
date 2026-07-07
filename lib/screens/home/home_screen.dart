import 'package:flutter/material.dart';
import '../planner/plan_editor_screen.dart';
import '../settings/settings_screen.dart';
import '../schedule/schedule_screen.dart';
import '../navigator/navigator_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openPlanEditor(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PlanEditorScreen(),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  void _openSchedule(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ScheduleScreen(),
      ),
    );
  }

  void _openNavigator(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NavigatorScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text("Disney Planner"),
        centerTitle: true,
        backgroundColor: const Color(0xFF6A5ACD),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [

            const SizedBox(height: 20),

            const Text(
              "🏰 Disney Planner",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "最高の1日をAIと一緒に作ろう",
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            _HomeButton(
              icon: Icons.edit_calendar,
              title: "プラン編集",
              subtitle: "行きたい施設を選択",
              onTap: () => _openPlanEditor(context),
            ),

            _HomeButton(
              icon: Icons.auto_awesome,
              title: "AIプラン生成",
              subtitle: "最適な1日を自動生成",
              onTap: () {},
            ),

            _HomeButton(
              icon: Icons.schedule,
              title: "今日の予定",
              subtitle: "AIが作成したスケジュール",
              onTap: () => _openSchedule(context),
            ),

            _HomeButton(
              icon: Icons.navigation,
              title: "当日ナビ",
              subtitle: "リアルタイムで次の目的地を案内",
              onTap: () => _openNavigator(context),
            ),

            _HomeButton(
              icon: Icons.settings,
              title: "設定",
              subtitle: "AI・入園設定",
              onTap: () => _openSettings(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        leading: Icon(
          icon,
          size: 32,
          color: const Color(0xFF6A5ACD),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}