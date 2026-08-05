import 'package:flutter/foundation.dart';

import '../../app/state/app_state.dart';
import '../../domain/entities/wish_item.dart';
import '../../domain/enums/wish_item_category.dart';

enum GuidedPlanningStep {
  welcome,
  mainFocus,
  seasonalEvent,
  freeDrink,
  foodInterests,
  entertainment,
  completed,
}

class GuidedPlanningController extends ChangeNotifier {
  GuidedPlanningController({required this.appState}) {
    _restorePackageSettings();
  }

  final AppState appState;

  GuidedPlanningStep step = GuidedPlanningStep.welcome;
  final Set<WishItemCategory> preferredCategories = {};

  bool usesVacationPackage = false;
  bool usesFreeDrink = false;
  bool wantsFeaturedFreeDrinkMenus = false;
  bool wantsEntertainment = false;
  bool wantsAttractions = false;
  bool wantsBalancedPlan = false;
  bool wantsSeasonalMenus = false;
  bool wantsSeasonalEntertainment = false;
  bool wantsSeasonalGoods = false;

  String get parkName => switch (appState.tripSettings.parkId) {
    'tokyo_disneyland' => '東京ディズニーランド',
    'tokyo_disneysea' => '東京ディズニーシー',
    _ => '選択中のパーク',
  };

  bool get shouldAskFreeDrink =>
      appState.tripSettings.usesVacationPackage &&
      appState.tripSettings.usesFreeDrinkBenefit;

  String get question => switch (step) {
    GuidedPlanningStep.welcome => '$parkNameのやりたいことを質問で整理します。',
    GuidedPlanningStep.mainFocus => '$parkNameで、特に重視したいものは何ですか？',
    GuidedPlanningStep.seasonalEvent => '$parkNameで、現在開催中の季節イベントを楽しみたいですか？',
    GuidedPlanningStep.freeDrink => 'フリードリンク券をどのように楽しみますか？',
    GuidedPlanningStep.foodInterests => '$parkNameの飲食では何を楽しみたいですか？',
    GuidedPlanningStep.entertainment => '$parkNameのショーやアトラクションも候補に含めますか？',
    GuidedPlanningStep.completed => '$parkNameでの希望を確認してください。',
  };

  String get selectionGuide => switch (step) {
    GuidedPlanningStep.seasonalEvent ||
    GuidedPlanningStep.foodInterests => '複数選択できます。もう一度押すと選択解除できます。',
    GuidedPlanningStep.welcome => '「始める」を押してください。',
    GuidedPlanningStep.completed => '',
    _ => '${options.length}つから1つ選択してください。',
  };

  List<String> get options => switch (step) {
    GuidedPlanningStep.welcome => const ['始める'],
    GuidedPlanningStep.mainFocus => const [
      'グルメを重視',
      'ショーを重視',
      'アトラクションを重視',
      'キャラクターを重視',
      'バランスよく',
    ],
    GuidedPlanningStep.seasonalEvent => const [
      '季節限定メニュー',
      '季節のショー・雰囲気',
      'イベントグッズ・スーベニア',
      '季節イベントをすべて',
      '季節イベントは重視しない',
    ],
    GuidedPlanningStep.freeDrink => const [
      '限定・店舗限定メニューをできるだけ全部',
      'スペシャルドリンクだけ',
      'スープ・ドリンクジュレも含める',
      '一覧から自分で選ぶ',
      '特に重視しない',
    ],
    GuidedPlanningStep.foodInterests => const [
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

  bool get isMultiSelectStep =>
      step == GuidedPlanningStep.seasonalEvent ||
      step == GuidedPlanningStep.foodInterests;
  bool get isFoodStep => step == GuidedPlanningStep.foodInterests;
  bool get canGoBack => step != GuidedPlanningStep.welcome;

  List<GuidedPlanningStep> get _steps => [
    GuidedPlanningStep.welcome,
    GuidedPlanningStep.mainFocus,
    GuidedPlanningStep.seasonalEvent,
    if (shouldAskFreeDrink) GuidedPlanningStep.freeDrink,
    GuidedPlanningStep.foodInterests,
    GuidedPlanningStep.entertainment,
  ];

  int get totalStepCount => _steps.length;
  int get currentStepNumber {
    final index = _steps.indexOf(step);
    return index < 0 ? _steps.length : index + 1;
  }

  void answer(String answer) {
    switch (step) {
      case GuidedPlanningStep.welcome:
        step = GuidedPlanningStep.mainFocus;
      case GuidedPlanningStep.mainFocus:
        wantsEntertainment = false;
        wantsAttractions = false;
        wantsBalancedPlan = false;
        preferredCategories.remove(WishItemCategory.greeting);
        if (answer == 'ショーを重視') {
          wantsEntertainment = true;
        } else if (answer == 'アトラクションを重視') {
          wantsAttractions = true;
        } else if (answer == 'キャラクターを重視') {
          preferredCategories.add(WishItemCategory.greeting);
        } else if (answer == 'バランスよく') {
          wantsBalancedPlan = true;
          wantsEntertainment = true;
          wantsAttractions = true;
          preferredCategories.add(WishItemCategory.greeting);
        }
        step = GuidedPlanningStep.seasonalEvent;
      case GuidedPlanningStep.seasonalEvent:
        _toggleSeasonal(answer);
      case GuidedPlanningStep.freeDrink:
        _applyFreeDrink(answer);
        step = GuidedPlanningStep.foodInterests;
      case GuidedPlanningStep.foodInterests:
        _toggleFood(answer);
      case GuidedPlanningStep.entertainment:
        wantsEntertainment = answer == 'ショーも含める' || answer == '両方含める';
        wantsAttractions = answer == 'アトラクションも含める' || answer == '両方含める';
        step = GuidedPlanningStep.completed;
      case GuidedPlanningStep.completed:
        break;
    }
    notifyListeners();
  }

  void confirmCurrentMultiSelection() {
    if (step == GuidedPlanningStep.seasonalEvent) {
      step = shouldAskFreeDrink
          ? GuidedPlanningStep.freeDrink
          : GuidedPlanningStep.foodInterests;
    } else if (step == GuidedPlanningStep.foodInterests) {
      step = GuidedPlanningStep.entertainment;
    }
    notifyListeners();
  }

  void confirmFoodSelection() => confirmCurrentMultiSelection();

  void _toggleSeasonal(String answer) {
    if (answer == '季節イベントをすべて') {
      final all =
          wantsSeasonalMenus &&
          wantsSeasonalEntertainment &&
          wantsSeasonalGoods;
      wantsSeasonalMenus = !all;
      wantsSeasonalEntertainment = !all;
      wantsSeasonalGoods = !all;
    } else if (answer == '季節限定メニュー') {
      wantsSeasonalMenus = !wantsSeasonalMenus;
    } else if (answer == '季節のショー・雰囲気') {
      wantsSeasonalEntertainment = !wantsSeasonalEntertainment;
    } else if (answer == 'イベントグッズ・スーベニア') {
      wantsSeasonalGoods = !wantsSeasonalGoods;
    } else if (answer == '季節イベントは重視しない') {
      wantsSeasonalMenus = false;
      wantsSeasonalEntertainment = false;
      wantsSeasonalGoods = false;
    }
  }

  void _applyFreeDrink(String answer) {
    wantsFeaturedFreeDrinkMenus = answer == '限定・店舗限定メニューをできるだけ全部';
    if (wantsFeaturedFreeDrinkMenus) {
      preferredCategories.addAll(_freeDrinkCategories);
    } else if (answer == 'スペシャルドリンクだけ') {
      preferredCategories.add(WishItemCategory.specialDrink);
    } else if (answer == 'スープ・ドリンクジュレも含める') {
      preferredCategories.addAll({
        WishItemCategory.specialDrink,
        WishItemCategory.soup,
        WishItemCategory.drinkJelly,
      });
    }
  }

  void _toggleFood(String answer) {
    if (answer == '飲食メニューをすべて') {
      _toggleCategories(_foodCategories);
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

  bool isOptionSelected(String option) => switch (option) {
    '季節限定メニュー' => wantsSeasonalMenus,
    '季節のショー・雰囲気' => wantsSeasonalEntertainment,
    'イベントグッズ・スーベニア' => wantsSeasonalGoods,
    '季節イベントをすべて' =>
      wantsSeasonalMenus && wantsSeasonalEntertainment && wantsSeasonalGoods,
    '季節イベントは重視しない' =>
      !wantsSeasonalMenus && !wantsSeasonalEntertainment && !wantsSeasonalGoods,
    '飲食メニューをすべて' => _foodCategories.every(preferredCategories.contains),
    'スペシャルドリンク' => preferredCategories.contains(WishItemCategory.specialDrink),
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

  void goBack() {
    if (step == GuidedPlanningStep.completed) {
      step = GuidedPlanningStep.entertainment;
    } else {
      final index = _steps.indexOf(step);
      if (index > 0) step = _steps[index - 1];
    }
    notifyListeners();
  }

  int applyToWishList(List<WishItem> items) {
    final parkId = appState.tripSettings.parkId;
    final matches = items
        .where((item) {
          if (item.parkId != parkId) return false;
          final seasonal = item.eventPackId != 'facility_master';
          final seasonalMatch =
              (wantsSeasonalMenus && _foodCategories.contains(item.category)) ||
              (wantsSeasonalEntertainment &&
                  item.category == WishItemCategory.entertainment) ||
              (wantsSeasonalGoods &&
                  {
                    WishItemCategory.goods,
                    WishItemCategory.souvenir,
                  }.contains(item.category));
          final normalMatch =
              preferredCategories.contains(item.category) ||
              (wantsEntertainment &&
                  item.category == WishItemCategory.entertainment) ||
              (wantsAttractions &&
                  item.category == WishItemCategory.attraction);
          if (!(normalMatch || (seasonal && seasonalMatch))) return false;
          if (wantsFeaturedFreeDrinkMenus &&
              item.category.isFreeDrinkMenuCategory) {
            return item.freeDrinkEligible;
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
    final parts = <String>['対象パーク：$parkName'];
    if (usesVacationPackage) {
      parts.add('バケーションパッケージ設定を反映');
    }
    if (wantsSeasonalMenus) parts.add('現在の季節限定メニュー');
    if (wantsSeasonalEntertainment) parts.add('現在の季節ショー・雰囲気');
    if (wantsSeasonalGoods) parts.add('現在のイベントグッズ・スーベニア');
    if (wantsFeaturedFreeDrinkMenus) {
      parts.add('フリードリンク対象の限定・店舗限定メニュー');
    }
    if (preferredCategories.isNotEmpty && !wantsFeaturedFreeDrinkMenus) {
      parts.add(preferredCategories.map((value) => value.label).join('・'));
    }
    if (wantsEntertainment) parts.add('ショーを候補に含める');
    if (wantsAttractions) parts.add('アトラクションを候補に含める');
    if (wantsBalancedPlan) parts.add('全体をバランスよく');
    return '今回の希望\n\n・${parts.join('\n・')}';
  }

  void restart() {
    step = GuidedPlanningStep.welcome;
    preferredCategories.clear();
    _restorePackageSettings();
    wantsFeaturedFreeDrinkMenus = false;
    wantsEntertainment = false;
    wantsAttractions = false;
    wantsBalancedPlan = false;
    wantsSeasonalMenus = false;
    wantsSeasonalEntertainment = false;
    wantsSeasonalGoods = false;
    notifyListeners();
  }

  void _restorePackageSettings() {
    usesVacationPackage = appState.tripSettings.usesVacationPackage;
    usesFreeDrink = appState.tripSettings.usesFreeDrinkBenefit;
  }

  static const Set<WishItemCategory> _freeDrinkCategories = {
    WishItemCategory.specialDrink,
    WishItemCategory.cafeDrink,
    WishItemCategory.juice,
    WishItemCategory.soup,
    WishItemCategory.drinkJelly,
  };

  static const Set<WishItemCategory> _foodCategories = {
    ..._freeDrinkCategories,
    WishItemCategory.food,
    WishItemCategory.dessert,
    WishItemCategory.snack,
  };
}
