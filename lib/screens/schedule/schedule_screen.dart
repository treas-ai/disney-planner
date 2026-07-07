import 'package:flutter/material.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  final List<Map<String, String>> sampleSchedule = const [
    {
      'time': '09:00',
      'title': '入園',
      'area': 'エントランス',
      'memo': '今日のプラン開始',
    },
    {
      'time': '09:20',
      'title': '美女と野獣“魔法のものがたり”',
      'area': 'ニューファンタジーランド',
      'memo': '優先度高',
    },
    {
      'time': '10:20',
      'title': 'ベイマックスのハッピーライド',
      'area': 'トゥモローランド',
      'memo': '待ち時間次第で調整',
    },
    {
      'time': '11:30',
      'title': 'クリスタルパレス・レストラン',
      'area': 'ワールドバザール',
      'memo': '予約想定',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text('今日の予定'),
        backgroundColor: const Color(0xFF6A5ACD),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sampleSchedule.length,
        itemBuilder: (context, index) {
          final item = sampleSchedule[index];

          return Card(
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
              subtitle: Text('${item['area']} / ${item['memo']}'),
            ),
          );
        },
      ),
    );
  }
}