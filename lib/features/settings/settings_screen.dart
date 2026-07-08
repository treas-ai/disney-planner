import 'package:flutter/material.dart';

import '../../core/widgets/app_card.dart';
import '../../core/widgets/section_title.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SectionTitle(
          title: '設定',
          subtitle: 'パーク、入園時間、人数などを管理する画面です。',
        ),
        AppCard(
          child: Text('v0.7でSharedPreferencesによる設定保存を追加予定です。'),
        ),
      ],
    );
  }
}