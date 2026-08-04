import 'package:flutter/material.dart';

import '../../../domain/entities/facility.dart';
import '../../../domain/enums/facility_category.dart';

class FacilityVisualStyle {
  const FacilityVisualStyle._();

  static FacilityCategoryVisual categoryStyle(Facility facility) {
    if (facility.isRestaurant) {
      return FacilityCategoryVisual(
        label: facility.restaurantType.label,
        icon: Icons.restaurant_outlined,
        backgroundColor: const Color(0xFF287A4B),
        foregroundColor: Colors.white,
      );
    }

    if (facility.isShop) {
      return FacilityCategoryVisual(
        label: facility.shopType.label,
        icon: Icons.storefront_outlined,
        backgroundColor: const Color(0xFFC06A00),
        foregroundColor: Colors.white,
      );
    }

    return categoryStyleForCategory(facility.category);
  }

  static FacilityCategoryVisual categoryStyleForCategory(
    FacilityCategory category,
  ) {
    return switch (category) {
      FacilityCategory.attraction => const FacilityCategoryVisual(
        label: 'アトラクション',
        icon: Icons.attractions_outlined,
        backgroundColor: Color(0xFF2457A6),
        foregroundColor: Colors.white,
      ),
      FacilityCategory.restaurant => const FacilityCategoryVisual(
        label: 'レストラン',
        icon: Icons.restaurant_outlined,
        backgroundColor: Color(0xFF287A4B),
        foregroundColor: Colors.white,
      ),
      FacilityCategory.show => const FacilityCategoryVisual(
        label: 'ショー・パレード',
        icon: Icons.theater_comedy_outlined,
        backgroundColor: Color(0xFF6A3DA1),
        foregroundColor: Colors.white,
      ),
      FacilityCategory.parade => const FacilityCategoryVisual(
        label: 'ショー・パレード',
        icon: Icons.theater_comedy_outlined,
        backgroundColor: Color(0xFF6A3DA1),
        foregroundColor: Colors.white,
      ),
      FacilityCategory.greeting => const FacilityCategoryVisual(
        label: 'グリーティング',
        icon: Icons.photo_camera_front_outlined,
        backgroundColor: Color(0xFF9A3F70),
        foregroundColor: Colors.white,
      ),
      FacilityCategory.shop => const FacilityCategoryVisual(
        label: 'ショップ',
        icon: Icons.storefront_outlined,
        backgroundColor: Color(0xFFC06A00),
        foregroundColor: Colors.white,
      ),
      FacilityCategory.service => const FacilityCategoryVisual(
        label: 'サービス',
        icon: Icons.info_outline,
        backgroundColor: Color(0xFF536873),
        foregroundColor: Colors.white,
      ),
    };
  }

  static FacilityAreaVisual areaStyle(String areaId) {
    return switch (areaId) {
      'tdl_world_bazaar' => const FacilityAreaVisual(
        label: 'ワールドバザール',
        icon: Icons.storefront_outlined,
        foregroundColor: Color(0xFF28496B),
        backgroundColor: Color(0xFFEAF1F7),
        borderColor: Color(0xFF7394B2),
      ),
      'tdl_adventureland' => const FacilityAreaVisual(
        label: 'アドベンチャーランド',
        icon: Icons.forest_outlined,
        foregroundColor: Color(0xFF2F6842),
        backgroundColor: Color(0xFFE8F3EB),
        borderColor: Color(0xFF78A989),
      ),
      'tdl_westernland' => const FacilityAreaVisual(
        label: 'ウエスタンランド',
        icon: Icons.landscape_outlined,
        foregroundColor: Color(0xFF805126),
        backgroundColor: Color(0xFFF5EDE4),
        borderColor: Color(0xFFB88C61),
      ),
      'tdl_critter_country' => const FacilityAreaVisual(
        label: 'クリッターカントリー',
        icon: Icons.pets_outlined,
        foregroundColor: Color(0xFF60743B),
        backgroundColor: Color(0xFFF0F4E7),
        borderColor: Color(0xFF9BAE71),
      ),
      'tdl_fantasyland' => const FacilityAreaVisual(
        label: 'ファンタジーランド',
        icon: Icons.castle_outlined,
        foregroundColor: Color(0xFFA04E78),
        backgroundColor: Color(0xFFFCECF4),
        borderColor: Color(0xFFD79AB7),
      ),
      'tdl_new_fantasyland' => const FacilityAreaVisual(
        label: 'ニューファンタジーランド',
        icon: Icons.auto_awesome_outlined,
        foregroundColor: Color(0xFF3977A3),
        backgroundColor: Color(0xFFEAF5FC),
        borderColor: Color(0xFF8CC1DF),
      ),
      'tdl_toontown' => const FacilityAreaVisual(
        label: 'トゥーンタウン',
        icon: Icons.house_outlined,
        foregroundColor: Color(0xFFB45616),
        backgroundColor: Color(0xFFFFF0E5),
        borderColor: Color(0xFFE7A472),
      ),
      'tdl_tomorrowland' => const FacilityAreaVisual(
        label: 'トゥモローランド',
        icon: Icons.rocket_launch_outlined,
        foregroundColor: Color(0xFF566B7D),
        backgroundColor: Color(0xFFEEF2F5),
        borderColor: Color(0xFFA5B3BE),
      ),
      'tdl_resort_hotels' => const FacilityAreaVisual(
        label: 'ディズニーホテル',
        icon: Icons.apartment_outlined,
        foregroundColor: Color(0xFF566B7D),
        backgroundColor: Color(0xFFEEF2F5),
        borderColor: Color(0xFFA5B3BE),
      ),
      'tds_mediterranean_harbor' => const FacilityAreaVisual(
        label: 'メディテレーニアンハーバー',
        icon: Icons.sailing_outlined,
        foregroundColor: Color(0xFF28567A),
        backgroundColor: Color(0xFFE8F1F7),
        borderColor: Color(0xFF79A2BE),
      ),
      'tds_american_waterfront' => const FacilityAreaVisual(
        label: 'アメリカンウォーターフロント',
        icon: Icons.directions_boat_outlined,
        foregroundColor: Color(0xFF874432),
        backgroundColor: Color(0xFFF8EBE7),
        borderColor: Color(0xFFC98B7B),
      ),
      'tds_port_discovery' => const FacilityAreaVisual(
        label: 'ポートディスカバリー',
        icon: Icons.explore_outlined,
        foregroundColor: Color(0xFF167B82),
        backgroundColor: Color(0xFFE4F5F5),
        borderColor: Color(0xFF72B9BC),
      ),
      'tds_lost_river_delta' => const FacilityAreaVisual(
        label: 'ロストリバーデルタ',
        icon: Icons.temple_buddhist_outlined,
        foregroundColor: Color(0xFF68702C),
        backgroundColor: Color(0xFFF2F3E4),
        borderColor: Color(0xFFA9AE70),
      ),
      'tds_arabian_coast' => const FacilityAreaVisual(
        label: 'アラビアンコースト',
        icon: Icons.nightlight_outlined,
        foregroundColor: Color(0xFF936B12),
        backgroundColor: Color(0xFFFFF6D9),
        borderColor: Color(0xFFD5B85C),
      ),
      'tds_mermaid_lagoon' => const FacilityAreaVisual(
        label: 'マーメイドラグーン',
        icon: Icons.water_outlined,
        foregroundColor: Color(0xFF167BA3),
        backgroundColor: Color(0xFFE5F7FC),
        borderColor: Color(0xFF75C4DD),
      ),
      'tds_mysterious_island' => const FacilityAreaVisual(
        label: 'ミステリアスアイランド',
        icon: Icons.terrain_outlined,
        foregroundColor: Color(0xFF8A3734),
        backgroundColor: Color(0xFFF8E9E8),
        borderColor: Color(0xFFC98581),
      ),
      'tds_fantasy_springs' => const FacilityAreaVisual(
        label: 'ファンタジースプリングス',
        icon: Icons.auto_awesome_outlined,
        foregroundColor: Color(0xFF24775F),
        backgroundColor: Color(0xFFE6F5EF),
        borderColor: Color(0xFF76B9A4),
      ),
      'tds_resort_hotels' => const FacilityAreaVisual(
        label: 'ディズニーホテル',
        icon: Icons.apartment_outlined,
        foregroundColor: Color(0xFF566B7D),
        backgroundColor: Color(0xFFEEF2F5),
        borderColor: Color(0xFFA5B3BE),
      ),
      'tds_parkwide' => const FacilityAreaVisual(
        label: 'パークワイド',
        icon: Icons.public_outlined,
        foregroundColor: Color(0xFF59656B),
        backgroundColor: Color(0xFFF0F3F4),
        borderColor: Color(0xFFB3BEC3),
      ),
      'tds_park_entrance' => const FacilityAreaVisual(
        label: 'パークエントランス',
        icon: Icons.door_front_door_outlined,
        foregroundColor: Color(0xFF59656B),
        backgroundColor: Color(0xFFF0F3F4),
        borderColor: Color(0xFFB3BEC3),
      ),
      _ => FacilityAreaVisual(
        label: areaId,
        icon: Icons.place_outlined,
        foregroundColor: const Color(0xFF59656B),
        backgroundColor: const Color(0xFFF0F3F4),
        borderColor: const Color(0xFFB3BEC3),
      ),
    };
  }
}

class FacilityCategoryVisual {
  const FacilityCategoryVisual({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
}

class FacilityAreaVisual {
  const FacilityAreaVisual({
    required this.label,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String label;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
}
