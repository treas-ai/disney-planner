import 'package:flutter/material.dart';
import '../../models/facility.dart';
import '../../services/facility_service.dart';
import '../../services/selection_service.dart';

class FacilityListScreen extends StatefulWidget {
  final String type;
  final String title;

  const FacilityListScreen({
    super.key,
    required this.type,
    required this.title,
  });

  @override
  State<FacilityListScreen> createState() => _FacilityListScreenState();
}

class _FacilityListScreenState extends State<FacilityListScreen> {
  late Future<List<Facility>> facilitiesFuture;
  final SelectionService selectionService = SelectionService();

  @override
  void initState() {
    super.initState();
    facilitiesFuture = _loadFacilitiesWithSavedSelection();
  }

  Future<List<Facility>> _loadFacilitiesWithSavedSelection() async {
    final facilities = await FacilityService().loadFacilities(widget.type);

    for (final facility in facilities) {
      final saved = await selectionService.loadSelected(
        type: facility.type,
        id: facility.id,
      );

      if (saved != null) {
        facility.selected = saved;
      }
    }

    return facilities;
  }

  Future<void> _toggleSelected(Facility item, bool value) async {
    setState(() {
      item.selected = value;
    });

    await selectionService.saveSelected(
      type: item.type,
      id: item.id,
      selected: value,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF6A5ACD),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Facility>>(
        future: facilitiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('読み込みエラー: ${snapshot.error}'),
            );
          }

          final facilities = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: facilities.length,
            itemBuilder: (context, index) {
              final item = facilities[index];

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
                    _toggleSelected(item, value ?? false);
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