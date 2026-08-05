import 'package:flutter/foundation.dart';

import '../../app/state/app_state.dart';
import '../../domain/entities/wish_item.dart';
import '../../domain/enums/wish_item_category.dart';

enum GuidedPlanningStep {
  welcome,
  mainFocus,
  vacationPackage,
  freeDrink,
  foodInterests,
  entertainment,
  completed,
}

class GuidedPlanningController extends ChangeNotifier {
  GuidedPlanningController({required this.appState});

  final AppState appState;

  GuidedPlanningStep step = GuidedPlanningStep.welcome;
  final Set<WishItemCategory> preferredCategories = {};
  bool usesVacationPackage = false;
  bool usesFreeDrink = false;
  bool wantsFeaturedFreeDrinkMenus = false;
  bool wantsEntertainment = false;
  bool wantsAttractions = false;
  bool wantsBalancedPlan = false;

  String get question {
    return switch (step) {
      GuidedPlanningStep.welcome => '質問に答えて、やりたいことを整理します。',
      GuidedPlanningStep.mainFocus => '今回、特に重視したいものは何ですか？',
      GuidedPlanningStep.vacationPackage => 'バケーションパッケージを利用しますか？',
      GuidedPlanningStep.freeDrink => 'フリードリンク券を活用しますか？',
      GuidedPlanningStep.foodInterests => '飲食では何を楽しみたいですか？',
      GuidedPlanningStep.entertainment => 'ショーやアトラクションも候補に含めますか？',
      GuidedPlanningStep.completed => '希望の整理が完了しました。',
    };
  }

  String get selectionGuide {
    return switch (step) {
      GuidedPlanningStep.foodInterests => '複数選択できます。もう一度押すと選択解除できます。',
      GuidedPlanningStep.mainFocus ||
      GuidedPlanningStep.entertainment => '${options.length}つから1つ選択してください。',
      GuidedPlanningStep.vacationPackage ||
      GuidedPlanningStep.freeDrink => 'どちらか1つ選択してください。',
      GuidedPlanningStep.welcome => '「始める」を押してください。',
      GuidedPlanningStep.completed => '',
    };
  }

  List<String> get options {
    return switch (step) {
      GuidedPlanningStep.welcome => const ['始める'],
      GuidedPlanningStep.mainFocus => const [
        'グルメを重視',
        'ショーを重視',
        'アトラクションを重視',
        'バランスよく',
      ],
      GuidedPlanningStep.vacationPackage => const ['利用する', '利用しない'],
      GuidedPlanningStep.freeDrink => const ['活用する', '使わない'],
      GuidedPlanningStep.foodInterests => const [
        'フリードリンク対象の限定・店舗限定メニューをすべて',
        '飲食メニューをすべて',
        'スペシャルドリンク',
        'コーヒー系・ジュース',
        'スープ・ドリンクジュレ',
        'フード・デザート',
        '飲食は選ばない',
      ],
      GuidedPlanningStep.entertainment => const [
        'ショーも含める',
        'アトラクションも含める',
        '両方含める',
        '飲食中心にする',
      ],
      GuidedPlanningStep.completed => const [],
    };
  }

  bool get isFoodStep => step == GuidedPlanningStep.foodInterests;
  bool get canGoBack => step != GuidedPlanningStep.welcome;
  int get totalStepCount => 6;

  int get currentStepNumber => switch (step) {
    GuidedPlanningStep.welcome => 1,
    GuidedPlanningStep.mainFocus => 2,
    GuidedPlanningStep.vacationPackage => 3,
    GuidedPlanningStep.freeDrink => 4,
    GuidedPlanningStep.foodInterests => 5,
    GuidedPlanningStep.entertainment => 6,
    GuidedPlanningStep.completed => 6,
  };

  void answer(String answer) {
    switch (step) {
      case GuidedPlanningStep.welcome:
        step = GuidedPlanningStep.mainFocus;
      case GuidedPlanningStep.mainFocus:
        wantsEntertainment = false;
        wantsAttractions = false;
        wantsBalancedPlan = false;
        if (answer == 'グルメを重視') {
          // 飲食の詳細は後の質問で選ぶ。
        } else if (answer == 'ショーを重視') {
          wantsEntertainment = true;
        } else if (answer == 'アトラクションを重視') {
          wantsAttractions = true;
        } else {
          wantsBalancedPlan = true;
          wantsEntertainment = true;
          wantsAttractions = true;
        }
        step = GuidedPlanningStep.vacationPackage;
      case GuidedPlanningStep.vacationPackage:
        usesVacationPackage = answer == '利用する';
        step = usesVacationPackage
            ? GuidedPlanningStep.freeDrink
            : GuidedPlanningStep.foodInterests;
      case GuidedPlanningStep.freeDrink:
        usesFreeDrink = answer == '活用する';
        if (!usesFreeDrink) wantsFeaturedFreeDrinkMenus = false;
        step = GuidedPlanningStep.foodInterests;
      case GuidedPlanningStep.foodInterests:
        _toggleFoodOption(answer);
      case GuidedPlanningStep.entertainment:
        wantsEntertainment = false;
        wantsAttractions = false;
        if (answer == 'ショーも含める') {
          wantsEntertainment = true;
        } else if (answer == 'アトラクションも含める') {
          wantsAttractions = true;
        } else if (answer == '両方含める') {
          wantsEntertainment = true;
          wantsAttractions = true;
        }
        step = GuidedPlanningStep.completed;
      case GuidedPlanningStep.completed:
        break;
    }
    notifyListeners();
  }

  void _toggleFoodOption(String answer) {
    if (answer == 'フリードリンク対象の限定・店舗限定メニューをすべて') {
      wantsFeaturedFreeDrinkMenus = !wantsFeaturedFreeDrinkMenus;
      if (wantsFeaturedFreeDrinkMenus) {
        usesFreeDrink = true;
        preferredCategories.addAll(_freeDrinkMenuCategories);
      } else {
        preferredCategories.removeAll(_freeDrinkMenuCategories);
      }
      return;
    }

    wantsFeaturedFreeDrinkMenus = false;
    if (answer == '飲食メニューをすべて') {
      if (_foodCategories.every(preferredCategories.contains)) {
        preferredCategories.removeAll(_foodCategories);
      } else {
        preferredCategories.addAll(_foodCategories);
      }
    } else if (answer == 'スペシャルドリンク') {
      _toggleCategories({WishItemCategory.specialDrink});
    } else if (answer == 'コーヒー系・ジュース') {
      _toggleCategories({WishItemCategory.cafeDrink, WishItemCategory.juice});
    } else if (answer == 'スープ・ドリンクジュレ') {
      _toggleCategories({WishItemCategory.soup, WishItemCategory.drinkJelly});
    } else if (answer == 'フード・デザート') {
      _toggleCategories({
        WishItemCategory.food,
        WishItemCategory.dessert,
        WishItemCategory.snack,
      });
    } else if (answer == '飲食は選ばない') {
      preferredCategories.removeAll(_foodCategories);
    }
  }

  void _toggleCategories(Set<WishItemCategory> categories) {
    if (categories.every(preferredCategories.contains)) {
      preferredCategories.removeAll(categories);
    } else {
      preferredCategories.addAll(categories);
    }
  }

  bool isOptionSelected(String option) {
    return switch (option) {
      'フリードリンク対象の限定・店舗限定メニューをすべて' => wantsFeaturedFreeDrinkMenus,
      '飲食メニューをすべて' => _foodCategories.every(preferredCategories.contains),
      'スペシャルドリンク' => preferredCategories.contains(
        WishItemCategory.specialDrink,
      ),
      'コーヒー系・ジュース' =>
        preferredCategories.contains(WishItemCategory.cafeDrink) &&
            preferredCategories.contains(WishItemCategory.juice),
      'スープ・ドリンクジュレ' =>
        preferredCategories.contains(WishItemCategory.soup) &&
            preferredCategories.contains(WishItemCategory.drinkJelly),
      'フード・デザート' =>
        preferredCategories.contains(WishItemCategory.food) &&
            preferredCategories.contains(WishItemCategory.dessert) &&
            preferredCategories.contains(WishItemCategory.snack),
      '飲食は選ばない' => !preferredCategories.any(_foodCategories.contains),
      _ => false,
    };
  }

  void confirmFoodSelection() {
    if (step != GuidedPlanningStep.foodInterests) return;
    step = GuidedPlanningStep.entertainment;
    notifyListeners();
  }

  void goBack() {
    step = switch (step) {
      GuidedPlanningStep.welcome => GuidedPlanningStep.welcome,
      GuidedPlanningStep.mainFocus => GuidedPlanningStep.welcome,
      GuidedPlanningStep.vacationPackage => GuidedPlanningStep.mainFocus,
      GuidedPlanningStep.freeDrink => GuidedPlanningStep.vacationPackage,
      GuidedPlanningStep.foodInterests =>
        usesVacationPackage
            ? GuidedPlanningStep.freeDrink
            : GuidedPlanningStep.vacationPackage,
      GuidedPlanningStep.entertainment => GuidedPlanningStep.foodInterests,
      GuidedPlanningStep.completed => GuidedPlanningStep.entertainment,
    };
    notifyListeners();
  }

  int applyToWishList(List<WishItem> items) {
    final parkId = appState.tripSettings.parkId;
    final matches = items
        .where((item) {
          if (item.parkId != parkId) return false;
          if (!preferredCategories.contains(item.category)) return false;
          if (wantsFeaturedFreeDrinkMenus) {
            // イベントパックは一般的なコーラ・お茶などを収録せず、
            // 限定・店舗限定・特徴的なメニューだけを管理する。
            return item.freeDrinkEligible &&
                item.category.isFreeDrinkMenuCategory;
          }
          if (usesFreeDrink && item.category.isFreeDrinkMenuCategory) {
            return item.freeDrinkEligible;
          }
          return true;
        })
        .map((item) => item.id)
        .toSet();

    appState.selectWishItems(matches);
    return matches.length;
  }

  String get summary {
    final parts = <String>[];
    if (usesVacationPackage) parts.add('バケーションパッケージ利用');
    if (wantsFeaturedFreeDrinkMenus) {
      parts.add('フリードリンク対象の限定・店舗限定メニューをすべて');
    } else if (usesFreeDrink) {
      parts.add('フリードリンク券を活用');
    }
    if (preferredCategories.isNotEmpty && !wantsFeaturedFreeDrinkMenus) {
      parts.add(preferredCategories.map((value) => value.label).join('・'));
    }
    if (wantsEntertainment) parts.add('ショーを候補に含める');
    if (wantsAttractions) parts.add('アトラクションを候補に含める');
    if (wantsBalancedPlan) parts.add('全体をバランスよく');
    if (parts.isEmpty) parts.add('一覧から手動で選択');
    return '今回の希望\n\n・${parts.join('\n・')}';
  }

  void restart() {
    step = GuidedPlanningStep.welcome;
    preferredCategories.clear();
    usesVacationPackage = false;
    usesFreeDrink = false;
    wantsFeaturedFreeDrinkMenus = false;
    wantsEntertainment = false;
    wantsAttractions = false;
    wantsBalancedPlan = false;
    notifyListeners();
  }

  static const Set<WishItemCategory> _freeDrinkMenuCategories = {
    WishItemCategory.specialDrink,
    WishItemCategory.cafeDrink,
    WishItemCategory.juice,
    WishItemCategory.soup,
    WishItemCategory.drinkJelly,
  };

  static const Set<WishItemCategory> _foodCategories = {
    ..._freeDrinkMenuCategories,
    WishItemCategory.food,
    WishItemCategory.dessert,
    WishItemCategory.snack,
  };
}
