import 'package:flutter/material.dart';

class AiPlannerScreen extends StatelessWidget {
  const AiPlannerScreen({super.key});

  final List<Map<String, String>> samplePlan = const [
    {
      'time': '09:00',
      'title': '入園',
      'reason': 'スタート地点',
    },
    {
      'time': '09:20',
      'title': '美女と野獣“魔法のものがたり”',
      'reason': '優先度が高く、朝に回したい施設',
    },
    {
      'time': '10:20',
      'title': 'ベイマックスのハッピーライド',
      'reason': '同じ方面に移動しやすいため',
    },
    {
      'time': '11:30',
      'title': 'クリスタルパレス・レストラン',
      'reason': '昼食枠として配置',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text('AIプラン生成'),
        backgroundColor: const Color(0xFF6A5ACD),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'AI生成プラン',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            '現在は仮表示です。次のステップで選択済み施設から自動生成します。',
          ),

          const SizedBox(height: 16),

          ...samplePlan.map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 14),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF6A5ACD),
                  foregroundColor: Colors.white,
                  child: Text(item['time']!),
                ),
                title: Text(
                  item['title']!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(item['reason']!),
              ),
            ),
          ),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.auto_awesome),
            label: const Text('この内容で今日の予定を作成'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6A5ACD),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}