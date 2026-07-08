import 'package:flutter/material.dart';

import '../../models/park_settings.dart';
import '../../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService settingsService = SettingsService();

  String park = '東京ディズニーランド';

  TimeOfDay entryTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay leaveTime = const TimeOfDay(hour: 21, minute: 0);

  bool happyEntry = false;
  bool useDpa = false;
  bool usePriorityPass = true;
  bool useSingleRider = false;
  bool lunch = true;
  bool dinner = true;
  bool rainMode = false;
  bool hasChildren = false;

  int people = 2;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await settingsService.loadSettings();

    setState(() {
      park = settings.park;
      entryTime = _parseTime(settings.entryTime);
      leaveTime = _parseTime(settings.leaveTime);
      people = settings.people;
      happyEntry = settings.happyEntry;
      useDpa = settings.useDpa;
      usePriorityPass = settings.usePriorityPass;
      useSingleRider = settings.useSingleRider;
      lunch = settings.lunch;
      dinner = settings.dinner;
      rainMode = settings.rainMode;
      hasChildren = settings.hasChildren;
    });
  }

  Future<void> _saveSettings() async {
    final settings = ParkSettings(
      park: park,
      entryTime: _formatTime(entryTime),
      leaveTime: _formatTime(leaveTime),
      people: people,
      happyEntry: happyEntry,
      useDpa: useDpa,
      usePriorityPass: usePriorityPass,
      useSingleRider: useSingleRider,
      lunch: lunch,
      dinner: dinner,
      rainMode: rainMode,
      hasChildren: hasChildren,
    );

    await settingsService.saveSettings(settings);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('設定を保存しました')),
    );
  }

  Future<void> _pickEntryTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: entryTime,
    );

    if (result != null) {
      setState(() {
        entryTime = result;
      });
    }
  }

  Future<void> _pickLeaveTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: leaveTime,
    );

    if (result != null) {
      setState(() {
        leaveTime = result;
      });
    }
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');

    if (parts.length != 2) {
      return const TimeOfDay(hour: 9, minute: 0);
    }

    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: const Color(0xFF6A5ACD),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'プラン条件',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: ListTile(
              title: const Text('パーク'),
              subtitle: Text(park),
              trailing: DropdownButton<String>(
                value: park,
                items: const [
                  DropdownMenuItem(
                    value: '東京ディズニーランド',
                    child: Text('ランド'),
                  ),
                  DropdownMenuItem(
                    value: '東京ディズニーシー',
                    child: Text('シー'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      park = value;
                    });
                  }
                },
              ),
            ),
          ),

          Card(
            child: ListTile(
              title: const Text('入園時間'),
              subtitle: Text(_formatTime(entryTime)),
              trailing: const Icon(Icons.access_time),
              onTap: _pickEntryTime,
            ),
          ),

          Card(
            child: ListTile(
              title: const Text('退園時間'),
              subtitle: Text(_formatTime(leaveTime)),
              trailing: const Icon(Icons.access_time),
              onTap: _pickLeaveTime,
            ),
          ),

          Card(
            child: ListTile(
              title: const Text('人数'),
              subtitle: Text('$people人'),
              trailing: DropdownButton<int>(
                value: people,
                items: List.generate(
                  8,
                  (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text('${index + 1}人'),
                  ),
                ),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      people = value;
                    });
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            '利用するサービス',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          SwitchListTile(
            title: const Text('ハッピーエントリー'),
            value: happyEntry,
            onChanged: (value) {
              setState(() {
                happyEntry = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text('DPAを利用'),
            value: useDpa,
            onChanged: (value) {
              setState(() {
                useDpa = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text('プライオリティパスを利用'),
            value: usePriorityPass,
            onChanged: (value) {
              setState(() {
                usePriorityPass = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text('シングルライダーを利用'),
            value: useSingleRider,
            onChanged: (value) {
              setState(() {
                useSingleRider = value;
              });
            },
          ),

          const SizedBox(height: 16),

          const Text(
            '食事',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          CheckboxListTile(
            title: const Text('昼食を入れる'),
            value: lunch,
            onChanged: (value) {
              setState(() {
                lunch = value ?? false;
              });
            },
          ),

          CheckboxListTile(
            title: const Text('夕食を入れる'),
            value: dinner,
            onChanged: (value) {
              setState(() {
                dinner = value ?? false;
              });
            },
          ),

          const SizedBox(height: 16),

          const Text(
            'その他',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          SwitchListTile(
            title: const Text('雨天モード'),
            value: rainMode,
            onChanged: (value) {
              setState(() {
                rainMode = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text('子供あり'),
            value: hasChildren,
            onChanged: (value) {
              setState(() {
                hasChildren = value;
              });
            },
          ),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            label: const Text('設定を保存'),
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