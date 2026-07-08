import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/section_title.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: ListView(
        children: [
          const SectionTitle(
            title: AppStrings.appName,
            subtitle: '世界中のディズニーパークに対応するAIプランナー',
            icon: AppIcons.homeSelected,
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.version,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(AppStrings.versionStatus),
              ],
            ),
          ),
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.nextStepTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                Text(AppStrings.nextStepDescription),
              ],
            ),
          ),
          AppButton(
            label: '共通ボタン表示テスト',
            icon: Icons.check_circle_outline,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('AppButtonは正常に動作しています。'),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
          const EmptyState(
            title: 'EmptyState 表示テスト',
            message: '今後、施設やプランがない場合にこの表示を使います。',
          ),
          const SizedBox(height: AppSpacing.xxl),
          const LoadingView(
            message: 'LoadingView 表示テスト',
          ),
        ],
      ),
    );
  }
}