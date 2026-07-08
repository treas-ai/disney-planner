import 'package:flutter/material.dart';
import '../../models/park_settings.dart';
import '../../services/settings_service.dart';
import '../../widgets/section_card.dart';
import '../planner/plan_editor_screen.dart';
import '../settings/settings_screen.dart';
import '../schedule/schedule_screen.dart';
import '../navigator/navigator_screen.dart';
import '../ai_planner/ai_planner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SettingsService settingsService = SettingsService();

  ParkSettings? settings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final loadedSettings = await settingsService.loadSettings();

    setState(() {
      settings = loadedSettings;
    });
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );

    _loadSettings();
  }

  void _openPlanEditor(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PlanEditorScreen(),
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

  void _openAiPlanner(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AiPlannerScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSettings = settings;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text('Disney Planner'),
        centerTitle: true,
        backgroundColor: const Color(0xFF6A5ACD),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 16),
          const Text(
            '🏰 Disney Planner',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '最高の1日をAIと一緒に作ろう',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          SectionCard(
            child: currentSettings == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '今日の状態',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('パーク：${currentSettings.park}'),
                      Text('入園時間：${currentSettings.entryTime}'),
                      Text('退園時間：${currentSettings.leaveTime}'),
                      Text('人数：${currentSettings.people}人'),
                    ],
                  ),
          ),

          _HomeMenuCard(
            icon: Icons.edit_calendar,
            title: 'プラン編集',
            subtitle: '行きたい施設を選択',
            onTap: () => _openPlanEditor(context),
          ),

          _HomeMenuCard(
            icon: Icons.auto_awesome,
            title: 'AIプラン生成',
            subtitle: '最適な1日を自動生成',
            onTap: () => _openAiPlanner(context),
          ),

          _HomeMenuCard(
            icon: Icons.schedule,
            title: '今日の予定',
            subtitle: 'AIが作成したスケジュール',
            onTap: () => _openSchedule(context),
          ),

          _HomeMenuCard(
            icon: Icons.navigation,
            title: '当日ナビ',
            subtitle: 'リアルタイムで次の目的地を案内',
            onTap: () => _openNavigator(context),
          ),

          _HomeMenuCard(
            icon: Icons.settings,
            title: '設定',
            subtitle: 'AI・入園設定',
            onTap: () => _openSettings(context),
          ),
        ],
      ),
    );
  }
}

class _HomeMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: 32,
            color: const Color(0xFF6A5ACD),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}