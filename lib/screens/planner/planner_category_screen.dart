import 'package:flutter/material.dart';
import 'planner_screen.dart';

class PlannerCategoryScreen extends StatelessWidget {
  const PlannerCategoryScreen({super.key});

  void _openAttractions(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PlannerScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text("プラン作成"),
        backgroundColor: const Color(0xFF6A5ACD),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _categoryCard(
            context,
            "🎢",
            "アトラクション",
            "乗りたいアトラクションを選択",
            () => _openAttractions(context),
          ),
          _categoryCard(
            context,
            "🎭",
            "ショー",
            "観たいショーを選択",
            () {},
          ),
          _categoryCard(
            context,
            "🍴",
            "レストラン",
            "食事候補を選択",
            () {},
          ),
          _categoryCard(
            context,
            "🛍",
            "ショップ",
            "寄りたいショップを選択",
            () {},
          ),
        ],
      ),
    );
  }

  Widget _categoryCard(
    BuildContext context,
    String icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      child: ListTile(
        leading: Text(
          icon,
          style: const TextStyle(fontSize: 30),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}