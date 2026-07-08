import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/section_title.dart';

class PlanEditorScreen extends StatelessWidget {
  const PlanEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: ListView(
        children: const [
          SectionTitle(
            title: 'プラン編集',
            subtitle: '行きたい施設を選び、優先度や希望時間を設定する画面です。',
            icon: AppIcons.planEditorSelected,
          ),
          AppCard(
            child: Text('v0.8でプラン編集機能を追加予定です。'),
          ),
        ],
      ),
    );
  }
}