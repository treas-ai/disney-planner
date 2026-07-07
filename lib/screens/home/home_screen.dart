import 'package:flutter/material.dart';
import '../planner/plan_editor_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text('Disney Planner'),
        centerTitle: true,
        backgroundColor: const Color(0xFF6A5ACD),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),

            const Text(
              '🏰 東京ディズニーランド',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              '最高の1日をAIと一緒に作ろう',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 40),

            _HomeButton(
              icon: Icons.edit_calendar,
              title: "プラン編集",
              subtitle: "行きたい施設を選択",
              onTap: () => _openPlanEditor(context),
            ),

            _HomeButton(
              icon: Icons.auto_awesome,
              title: "AIプラン生成",
              subtitle: "最適な1日を自動作成",
              onTap: () {},
            ),

            _HomeButton(
              icon: Icons.schedule,
              title: "今日の予定",
              subtitle: "作成したプランを見る",
              onTap: () {},
            ),

            _HomeButton(
              icon: Icons.navigation,
              title: "当日ナビ",
              subtitle: "現在地から次を案内",
              onTap: () {},
            ),

            _HomeButton(
              icon: Icons.settings,
              title: "設定",
              subtitle: "アプリ設定",
              onTap: () {},
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
          color: const Color(0xFF6A5ACD),
          size: 32,
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