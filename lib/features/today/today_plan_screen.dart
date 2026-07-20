import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/section_title.dart';

class TodayPlanScreen extends StatelessWidget {
  const TodayPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: ListView(
        children: const [
          SectionTitle(
            title: '今日の予定',
            subtitle: '採用済みプランを当日に確認する画面です。',
            icon: AppIcons.todaySelected,
          ),
          AppCard(child: Text('v1.0で採用済みプランを表示予定です。')),
        ],
      ),
    );
  }
}
