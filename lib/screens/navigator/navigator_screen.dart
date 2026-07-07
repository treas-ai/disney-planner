import 'package:flutter/material.dart';

class NavigatorScreen extends StatelessWidget {
  const NavigatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text('当日ナビ'),
        backgroundColor: const Color(0xFF6A5ACD),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: ListTile(
              leading: Icon(Icons.place, color: Color(0xFF6A5ACD)),
              title: Text('現在地'),
              subtitle: Text('ワールドバザール'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.access_time, color: Color(0xFF6A5ACD)),
              title: Text('現在時刻'),
              subtitle: Text('09:30'),
            ),
          ),
          SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(Icons.auto_awesome, color: Color(0xFF6A5ACD)),
              title: Text(
                '次のおすすめ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('美女と野獣“魔法のものがたり”\n徒歩10分 / 優先度高'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.restaurant, color: Color(0xFF6A5ACD)),
              title: Text('近くの候補'),
              subtitle: Text('ラ・タベルヌ・ド・ガストン\nビレッジショップス'),
            ),
          ),
        ],
      ),
    );
  }
}