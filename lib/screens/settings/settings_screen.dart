import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("プラン設定"),
      ),
      body: ListView(
        children: [

          const ListTile(
            title: Text(
              "基本設定",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          SwitchListTile(
            title: const Text("ハッピーエントリー"),
            value: happyEntry,
            onChanged: (v) => setState(() => happyEntry = v),
          ),

          SwitchListTile(
            title: const Text("DPAを利用"),
            value: useDpa,
            onChanged: (v) => setState(() => useDpa = v),
          ),

          SwitchListTile(
            title: const Text("プライオリティパスを利用"),
            value: usePriorityPass,
            onChanged: (v) => setState(() => usePriorityPass = v),
          ),

          SwitchListTile(
            title: const Text("シングルライダー利用"),
            value: useSingleRider,
            onChanged: (v) => setState(() => useSingleRider = v),
          ),

          const Divider(),

          const ListTile(
            title: Text(
              "食事",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          CheckboxListTile(
            title: const Text("昼食を取る"),
            value: lunch,
            onChanged: (v) => setState(() => lunch = v!),
          ),

          CheckboxListTile(
            title: const Text("夕食を取る"),
            value: dinner,
            onChanged: (v) => setState(() => dinner = v!),
          ),

          const Divider(),

          const ListTile(
            title: Text(
              "その他",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          SwitchListTile(
            title: const Text("雨の日モード"),
            value: rainMode,
            onChanged: (v) => setState(() => rainMode = v),
          ),

          SwitchListTile(
            title: const Text("子供がいる"),
            value: hasChildren,
            onChanged: (v) => setState(() => hasChildren = v),
          ),

          ListTile(
            title: const Text("人数"),
            subtitle: Text("$people 人"),
            trailing: DropdownButton<int>(
              value: people,
              items: List.generate(
                8,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text("${i + 1}人"),
                ),
              ),
              onChanged: (v) {
                setState(() {
                  people = v!;
                });
              },
            ),
          ),

          const SizedBox(height: 30),

          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () {},
              child: const Text("設定を保存"),
            ),
          ),
        ],
      ),
    );
  }
}