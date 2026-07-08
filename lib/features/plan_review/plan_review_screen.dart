import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/section_title.dart';

class PlanReviewScreen extends StatelessWidget {
  const PlanReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: ListView(
        children: const [
          SectionTitle(
            title: 'プラン確認',
            subtitle: '生成されたプランと理由を確認する画面です。',
            icon: AppIcons.planReviewSelected,
          ),
          AppCard(
            child: Text('v0.9で簡易プラン生成、v1.0で採用機能を追加予定です。'),
          ),
        ],
      ),
    );
  }
}