import 'package:flutter/material.dart';
import '../../models/attraction.dart';
import '../../services/attraction_service.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late Future<List<Attraction>> attractionsFuture;

  @override
  void initState() {
    super.initState();
    attractionsFuture = AttractionService().loadAttractions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text('プラン作成'),
        backgroundColor: const Color(0xFF6A5ACD),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Attraction>>(
        future: attractionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('読み込みエラー: ${snapshot.error}'),
            );
          }

          final attractions = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: attractions.length,
            itemBuilder: (context, index) {
              final item = attractions[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: CheckboxListTile(
                  value: item.selected,
                  activeColor: const Color(0xFF6A5ACD),
                  title: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${item.area} / ${item.durationMinutes}分 / 優先度 ${item.priority}',
                  ),
                  onChanged: (value) {
                    setState(() {
                      item.selected = value ?? false;
                    });
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}