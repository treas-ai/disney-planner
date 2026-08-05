import 'package:flutter/material.dart';

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
    GuidedPlanningStep.mainFocus => '1日の満足度を上げるため、最優先にしたい体験はどれですか？',
    GuidedPlanningStep.seasonalEvent => '開催中の季節イベントで、プランへ優先して入れたいものを選んでください。',
    GuidedPlanningStep.freeDrink => 'フリードリンク券を使う場合、どの範囲をプランへ組み込みますか？',
    GuidedPlanningStep.foodInterests => '食事や休憩として、プランへ入れたい飲食ジャンルを選んでください。',
    GuidedPlanningStep.entertainment => '飲食以外の体験を、どこまでプラン候補へ含めますか？',
    GuidedPlanningStep.completed => '$parkNameでの希望を確認してください。',
  };

  String get selectionGuide => switch (step) {
    GuidedPlanningStep.seasonalEvent ||
    GuidedPlanningStep.foodInterests => '複数選択できます。選択した項目にはチェックが付きます。',
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



  String optionDescription(String option) => switch (option) {
    '始める' => '5つの質問で、実行しやすい候補へ絞り込みます',
    'グルメを重視' => '食事・限定フード・ドリンクの時間を優先',
    'ショーを重視' => '公演時刻を軸に1日の流れを組み立てる',
    'アトラクションを重視' => '乗車できる件数と待ち時間短縮を優先',
    'キャラクターを重視' => 'グリーティングを優先候補として扱う',
    'バランスよく' => '飲食・ショー・アトラクションを無理なく配分',
    '季節限定メニュー' => '期間限定のフードやドリンクを候補に追加',
    '季節のショー・雰囲気' => '季節公演やイベントらしい体験を優先',
    'イベントグッズ・スーベニア' => '買い物やスーベニア取得時間も確保',
    '季節イベントをすべて' => 'メニュー・公演・グッズをまとめて選択',
    '季節イベントは重視しない' => '通常施設を中心に候補を作成',
    '限定・店舗限定メニューをできるだけ全部' => '対象メニューを広く拾い、移動中にも配置',
    'スペシャルドリンクだけ' => '限定ドリンクを中心に短時間で取得',
    'スープ・ドリンクジュレも含める' => '軽食代わりになる対象メニューも追加',
    '一覧から自分で選ぶ' => '質問後の一覧画面で個別に選択',
    '特に重視しない' => 'フリードリンクをプランの優先条件にしない',
    '飲食メニューをすべて' => 'フード・デザート・対象ドリンクを広く候補化',
    'スペシャルドリンク' => '季節・期間限定ドリンクを優先',
    'コーヒー系・ジュース' => '休憩に入れやすい飲み物を候補化',
    'スープ・ドリンクジュレ' => '短時間で楽しめる軽食系メニューを追加',
    'フード・デザート' => '食事・軽食・甘いものを候補化',
    '飲食は選ばない' => '飲食候補を自動追加しない',
    'ショーも含める' => '公演時刻を考慮してショーを候補に追加',
    'アトラクションも含める' => '待ち時間を考慮して乗り物を候補に追加',
    '両方含める' => 'ショーとアトラクションを両方評価',
    '飲食中心にする' => '飲食候補を中心にし、体験施設は追加しない',
    _ => '',
  };

  IconData optionIcon(String option) => switch (option) {
    '始める' => Icons.play_arrow_rounded,
    'グルメを重視' => Icons.restaurant_rounded,
    'ショーを重視' => Icons.theater_comedy_rounded,
    'アトラクションを重視' => Icons.attractions_rounded,
    'キャラクターを重視' => Icons.face_rounded,
    'バランスよく' => Icons.balance_rounded,
    '季節限定メニュー' => Icons.restaurant_menu_rounded,
    '季節のショー・雰囲気' => Icons.celebration_rounded,
    'イベントグッズ・スーベニア' => Icons.shopping_bag_rounded,
    '季節イベントをすべて' => Icons.select_all_rounded,
    '季節イベントは重視しない' => Icons.not_interested_rounded,
    '限定・店舗限定メニューをできるだけ全部' => Icons.local_drink_rounded,
    'スペシャルドリンクだけ' => Icons.local_cafe_rounded,
    'スープ・ドリンクジュレも含める' => Icons.soup_kitchen_rounded,
    '一覧から自分で選ぶ' => Icons.checklist_rounded,
    '特に重視しない' => Icons.remove_circle_outline_rounded,
    '飲食メニューをすべて' => Icons.done_all_rounded,
    'スペシャルドリンク' => Icons.local_bar_rounded,
    'コーヒー系・ジュース' => Icons.coffee_rounded,
    'スープ・ドリンクジュレ' => Icons.soup_kitchen_rounded,
    'フード・デザート' => Icons.cake_rounded,
    '飲食は選ばない' => Icons.no_food_rounded,
    'ショーも含める' => Icons.theater_comedy_rounded,
    'アトラクションも含める' => Icons.attractions_rounded,
    '両方含める' => Icons.auto_awesome_rounded,
    '飲食中心にする' => Icons.restaurant_rounded,
    _ => Icons.check_circle_outline_rounded,
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
    appState.clearWishSelection();
    appState.selectWishItems(matches);
    return matches.length;
  }

  List<String> get summaryItems {
    final parts = <String>[];
    if (usesVacationPackage) {
      parts.add('バケーションパッケージ');
    }
    if (wantsSeasonalMenus) parts.add('季節限定メニュー');
    if (wantsSeasonalEntertainment) parts.add('季節ショー・雰囲気');
    if (wantsSeasonalGoods) parts.add('イベントグッズ');
    if (wantsFeaturedFreeDrinkMenus) {
      parts.add('フリードリンク限定メニュー');
    }
    if (preferredCategories.isNotEmpty && !wantsFeaturedFreeDrinkMenus) {
      parts.addAll(preferredCategories.map((value) => value.label));
    }
    if (wantsEntertainment) parts.add('ショー');
    if (wantsAttractions) parts.add('アトラクション');
    if (wantsBalancedPlan) parts.add('バランス重視');
    return parts.toSet().toList(growable: false);
  }

  String get summary {
    final parts = <String>['対象パーク：$parkName', ...summaryItems];
    return '今回の希望\n\n・${parts.join('\n・')}';
  }

  void restart({bool clearWishSelection = false}) {
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
    if (clearWishSelection) {
      appState.clearWishSelection();
    }
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
