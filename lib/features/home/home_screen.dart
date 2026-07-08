import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/section_title.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/park.dart';
import 'home_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const LoadingView(message: 'ホームデータを読み込み中です...');
          }

          if (_controller.errorMessage != null) {
            return EmptyState(
              title: '読み込みエラー',
              message: _controller.errorMessage!,
              icon: Icons.error_outline,
            );
          }

          if (_controller.resorts.isEmpty &&
              _controller.parks.isEmpty &&
              _controller.facilities.isEmpty) {
            return const EmptyState(
              title: 'データがありません',
              message: 'Repositoryからデータを取得できませんでした。',
            );
          }

          return ListView(
            children: [
              const SectionTitle(
                title: AppStrings.appName,
                subtitle: 'RepositoryとMockDataSourceを接続しました。',
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
              _SummaryCard(
                resortCount: _controller.resorts.length,
                parkCount: _controller.parks.length,
                facilityCount: _controller.facilities.length,
              ),
              _ParkListCard(parks: _controller.parks),
              _FacilityListCard(facilities: _controller.facilities),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.resortCount,
    required this.parkCount,
    required this.facilityCount,
  });

  final int resortCount;
  final int parkCount;
  final int facilityCount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'データ概要',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('リゾート数：$resortCount'),
          Text('パーク数：$parkCount'),
          Text('施設数：$facilityCount'),
        ],
      ),
    );
  }
}

class _ParkListCard extends StatelessWidget {
  const _ParkListCard({
    required this.parks,
  });

  final List<Park> parks;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'パーク一覧',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final park in parks) ...[
            Text('・${park.name}'),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _FacilityListCard extends StatelessWidget {
  const _FacilityListCard({
    required this.facilities,
  });

  final List<Facility> facilities;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '代表施設',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final facility in facilities) ...[
            Text('・${facility.name}（${facility.category.label}）'),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}