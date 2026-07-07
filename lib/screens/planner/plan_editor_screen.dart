import 'package:flutter/material.dart';
import '../../models/facility.dart';
import '../../services/facility_service.dart';
import '../../services/selection_service.dart';
import 'facility_list_screen.dart';

class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({super.key});

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  final SelectionService selectionService = SelectionService();

  int attractionCount = 0;
  int showCount = 0;
  int restaurantCount = 0;
  int shopCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final attractions = await _countSelected('attraction');
    final shows = await _countSelected('show');
    final restaurants = await _countSelected('restaurant');
    final shops = await _countSelected('shop');

    setState(() {
      attractionCount = attractions;
      showCount = shows;
      restaurantCount = restaurants;
      shopCount = shops;
    });
  }

  Future<int> _countSelected(String type) async {
    final List<Facility> facilities =
        await FacilityService().loadFacilities(type);

    int count = 0;

    for (final facility in facilities) {
      final saved = await selectionService.loadSelected(
        type: facility.type,
        id: facility.id,
      );

      final isSelected = saved ?? facility.selected;

      if (isSelected) {
        count++;
      }
    }

    return count;
  }

  Future<void> _openFacilityList(
    BuildContext context, {
    required String type,
    required String title,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FacilityListScreen(
          type: type,
          title: title,
        ),
      ),
    );

    _loadCounts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text('プラン編集'),
        backgroundColor: const Color(0xFF6A5ACD),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '今日やりたいことを選びましょう',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _PlanCategoryCard(
            icon: '🎢',
            title: 'アトラクション',
            subtitle: '選択済み $attractionCount件',
            onTap: () => _openFacilityList(
              context,
              type: 'attraction',
              title: 'アトラクション',
            ),
          ),
          _PlanCategoryCard(
            icon: '🎭',
            title: 'ショー',
            subtitle: '選択済み $showCount件',
            onTap: () => _openFacilityList(
              context,
              type: 'show',
              title: 'ショー',
            ),
          ),
          _PlanCategoryCard(
            icon: '🍴',
            title: 'レストラン',
            subtitle: '選択済み $restaurantCount件',
            onTap: () => _openFacilityList(
              context,
              type: 'restaurant',
              title: 'レストラン',
            ),
          ),
          _PlanCategoryCard(
            icon: '🛍',
            title: 'ショップ',
            subtitle: '選択済み $shopCount件',
            onTap: () => _openFacilityList(
              context,
              type: 'shop',
              title: 'ショップ',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.auto_awesome),
            label: const Text('AIでプラン生成'),
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

class _PlanCategoryCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PlanCategoryCard({
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
        leading: Text(
          icon,
          style: const TextStyle(fontSize: 30),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}