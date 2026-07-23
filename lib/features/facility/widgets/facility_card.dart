import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/facility.dart';
import '../../../domain/enums/restaurant_type.dart';
import '../../../domain/enums/shop_type.dart';

class FacilityCard extends StatelessWidget {
  const FacilityCard({
    super.key,
    required this.facility,
    required this.isSelected,
    required this.onAdd,
    required this.onRemove,
  });

  final Facility facility;
  final bool isSelected;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final serviceTags = _buildServiceTags(facility);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FacilityHeader(facility: facility),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _InformationChip(
                icon: _categoryIcon(facility),
                label: _categoryLabel(facility),
              ),
              _InformationChip(
                icon: Icons.schedule_outlined,
                label: '利用目安 約${facility.durationMinutes}分',
              ),
            ],
          ),
          if (serviceTags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: serviceTags,
            ),
          ],
          if (facility.isShowRestaurant) ...[
            const SizedBox(height: AppSpacing.sm),
            _ShowRestaurantInformation(
              showName: facility.showName ?? 'ショーレストラン',
            ),
          ],
          if (facility.primaryProductLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _RepresentativeInformation(facility: facility),
          ],
          if (facility.menuNote != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              facility.menuNote!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (facility.description != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              facility.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (facility.hasMenuUrl || facility.hasOfficialUrl) ...[
            const SizedBox(height: AppSpacing.md),
            _OfficialLinkButtons(facility: facility),
          ],
          if (facility.isOpen) ...[
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                label: isSelected ? '追加済み' : '追加',
                icon: isSelected ? Icons.check : Icons.add,
                onPressed: isSelected ? onRemove : onAdd,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static List<Widget> _buildServiceTags(Facility facility) {
    final tags = <Widget>[];

    if (facility.supportsDpa) {
      tags.add(
        const _ServiceTag(
          icon: Icons.bolt_outlined,
          label: 'DPA',
          type: _ServiceTagType.dpa,
        ),
      );
    }

    if (facility.supportsPriorityPass) {
      tags.add(
        const _ServiceTag(
          icon: Icons.confirmation_number_outlined,
          label: 'プライオリティパス',
          type: _ServiceTagType.priorityPass,
        ),
      );
    }

    if (facility.supportsSingleRider) {
      tags.add(
        const _ServiceTag(
          icon: Icons.person_outline,
          label: 'シングルライダー',
          type: _ServiceTagType.singleRider,
        ),
      );
    }

    if (facility.requiresEntryRequest) {
      tags.add(
        const _ServiceTag(
          icon: Icons.how_to_reg_outlined,
          label: 'エントリー受付',
          type: _ServiceTagType.entryRequest,
        ),
      );
    }

    if (facility.supportsStandbyPass) {
      tags.add(
        const _ServiceTag(
          icon: Icons.airplane_ticket_outlined,
          label: 'スタンバイパス',
          type: _ServiceTagType.standbyPass,
        ),
      );
    }

    if (facility.supportsMobileOrder) {
      tags.add(
        const _ServiceTag(
          icon: Icons.phone_android_outlined,
          label: 'モバイルオーダー',
          type: _ServiceTagType.mobileOrder,
        ),
      );
    }

    if (facility.supportsPrioritySeating) {
      tags.add(
        const _ServiceTag(
          icon: Icons.event_available_outlined,
          label: 'プライオリティ・シーティング',
          type: _ServiceTagType.prioritySeating,
        ),
      );
    }

    if (facility.requiresReservation || facility.reservationRequired) {
      tags.add(
        const _ServiceTag(
          icon: Icons.lock_clock_outlined,
          label: '予約必須',
          type: _ServiceTagType.reservation,
        ),
      );
    }

    if (!facility.isOpen) {
      tags.add(
        const _ServiceTag(
          icon: Icons.block_outlined,
          label: '休止中',
          type: _ServiceTagType.closed,
        ),
      );
    }

    return tags;
  }

  static String _categoryLabel(Facility facility) {
    if (facility.isShowRestaurant) {
      return 'ショーレストラン';
    }

    if (facility.isPopcornWagon) {
      return 'ポップコーンワゴン';
    }

    if (facility.isRestaurant &&
        facility.restaurantType != RestaurantType.none) {
      return facility.restaurantType.label;
    }

    if (facility.isShop && facility.shopType != ShopType.none) {
      return facility.shopType.label;
    }

    return facility.category.label;
  }

  static IconData _categoryIcon(Facility facility) {
    if (facility.isShowRestaurant) {
      return Icons.theater_comedy_outlined;
    }

    if (facility.isPopcornWagon) {
      return Icons.local_movies_outlined;
    }

    if (facility.isRestaurant) {
      return Icons.restaurant_outlined;
    }

    if (facility.isShop) {
      return Icons.shopping_bag_outlined;
    }

    return switch (facility.category.name) {
      'attraction' => Icons.attractions_outlined,
      'show' => Icons.theater_comedy_outlined,
      'parade' => Icons.celebration_outlined,
      'greeting' => Icons.photo_camera_front_outlined,
      _ => Icons.place_outlined,
    };
  }
}

class _OfficialLinkButtons extends StatelessWidget {
  const _OfficialLinkButtons({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        if (facility.hasMenuUrl)
          OutlinedButton.icon(
            onPressed: () {
              _openUrl(context, facility.menuUrl!);
            },
            icon: const Icon(Icons.restaurant_menu_outlined, size: 18),
            label: const Text('メニューを見る'),
          ),
        if (facility.hasOfficialUrl)
          TextButton.icon(
            onPressed: () {
              _openUrl(context, facility.officialUrl!);
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('公式ページを見る'),
          ),
      ],
    );
  }

  Future<void> _openUrl(BuildContext context, String value) async {
    final uri = Uri.tryParse(value.trim());

    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      _showError(context, 'リンクが正しく設定されていません。');
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened && context.mounted) {
        _showError(context, '公式ページを開けませんでした。');
      }
    } catch (_) {
      if (context.mounted) {
        _showError(context, '公式ページを開けませんでした。');
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FacilityHeader extends StatelessWidget {
  const _FacilityHeader({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            facility.name,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          facility.priority.stars,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _RepresentativeInformation extends StatelessWidget {
  const _RepresentativeInformation({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final popcornFlavor = facility.popcornFlavor?.trim();

    final isPopcorn = popcornFlavor != null && popcornFlavor.isNotEmpty;

    final product = facility.primaryProductLabel;

    if (product == null) {
      return const SizedBox.shrink();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isPopcorn
              ? Icons.local_movies_outlined
              : facility.isShop
              ? Icons.shopping_bag_outlined
              : Icons.restaurant_menu_outlined,
          size: 19,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            isPopcorn ? product : '代表：$product',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _ShowRestaurantInformation extends StatelessWidget {
  const _ShowRestaurantInformation({required this.showName});

  final String showName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.34),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.theater_comedy_outlined,
            size: 19,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              showName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationChip extends StatelessWidget {
  const _InformationChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 17),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ServiceTag extends StatelessWidget {
  const _ServiceTag({
    required this.icon,
    required this.label,
    required this.type,
  });

  final IconData icon;
  final String label;
  final _ServiceTagType type;

  @override
  Widget build(BuildContext context) {
    final colors = _ServiceTagColors.resolve(context, type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ServiceTagType {
  dpa,
  priorityPass,
  singleRider,
  entryRequest,
  standbyPass,
  mobileOrder,
  prioritySeating,
  reservation,
  closed,
}

class _ServiceTagColors {
  const _ServiceTagColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;

  static _ServiceTagColors resolve(BuildContext context, _ServiceTagType type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return switch (type) {
      _ServiceTagType.dpa => _fromBaseColor(
        isDark ? Colors.lightBlueAccent : Colors.blue,
        isDark: isDark,
      ),
      _ServiceTagType.priorityPass => _fromBaseColor(
        isDark ? Colors.deepPurpleAccent : Colors.deepPurple,
        isDark: isDark,
      ),
      _ServiceTagType.singleRider => _fromBaseColor(
        isDark ? Colors.lightGreenAccent : Colors.green,
        isDark: isDark,
      ),
      _ServiceTagType.entryRequest => _fromBaseColor(
        isDark ? Colors.orangeAccent : Colors.deepOrange,
        isDark: isDark,
      ),
      _ServiceTagType.standbyPass => _fromBaseColor(
        isDark ? Colors.yellowAccent : Colors.amber.shade800,
        isDark: isDark,
      ),
      _ServiceTagType.mobileOrder => _fromBaseColor(
        isDark ? Colors.greenAccent : Colors.teal,
        isDark: isDark,
      ),
      _ServiceTagType.prioritySeating => _fromBaseColor(
        isDark ? Colors.pinkAccent : Colors.pink,
        isDark: isDark,
      ),
      _ServiceTagType.reservation => _fromBaseColor(
        isDark ? Colors.redAccent : Colors.red,
        isDark: isDark,
      ),
      _ServiceTagType.closed => _fromBaseColor(
        isDark ? Colors.grey.shade400 : Colors.grey.shade700,
        isDark: isDark,
      ),
    };
  }

  static _ServiceTagColors _fromBaseColor(
    Color baseColor, {
    required bool isDark,
  }) {
    return _ServiceTagColors(
      background: baseColor.withValues(alpha: isDark ? 0.20 : 0.10),
      foreground: baseColor,
      border: baseColor.withValues(alpha: isDark ? 0.55 : 0.30),
    );
  }
}
