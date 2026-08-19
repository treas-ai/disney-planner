import 'package:flutter/material.dart';

import '../../app/state/app_state.dart';
import '../../app/dependency/service_locator.dart';
import '../../data/repositories/crowd_factor_repository_impl.dart';
import '../../domain/entities/facility.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/services/dynamic_wait_scoring_service.dart';
import '../../domain/entities/wish_item.dart';
import '../../domain/enums/wish_item_category.dart';

enum GuidedPlanningStep {
  welcome,
  mainFocus,
  focusDetail,
  secondaryExperience,
  foodStyle,
  freeDrinkPreference,
  characterInterest,
  seasonalPreference,
  completed,
}

enum GuidedPlanningFocus {
  attractions,
  entertainment,
  characters,
  food,
  balanced,
  aiChoice,
}

enum GuidedPlanningDebugPreset {
  attractionThrill('アトラクション／スリル重視'),
  attractionStory('アトラクション／世界観重視'),
  entertainment('ショー・パレード重視'),
  seasonalFood('フード／季節限定重視'),
  characters('キャラクター重視'),
  balanced('バランス'),
  aiChoice('AIおまかせ'),
  allIn('全部入り');

  const GuidedPlanningDebugPreset(this.label);

  final String label;
}

class GuidedPlanningController extends ChangeNotifier {
  GuidedPlanningController({required this.appState}) {
    _restorePackageSettings();
  }

  final AppState appState;

  GuidedPlanningStep step = GuidedPlanningStep.welcome;
  GuidedPlanningFocus? primaryFocus;
  String? focusDetailAnswer;
  String? secondaryExperienceAnswer;
  String? foodStyleAnswer;
  String? freeDrinkPreferenceAnswer;
  String? characterInterestAnswer;
  String? seasonalPreferenceAnswer;

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

  bool get hasFreeDrinkBenefit =>
      usesVacationPackage && usesFreeDrink;

  String get parkName => switch (appState.tripSettings.parkId) {
    'tokyo_disneyland' => '東京ディズニーランド',
    'tokyo_disneysea' => '東京ディズニーシー',
    _ => '選択中のパーク',
  };

  String get question => switch (step) {
    GuidedPlanningStep.welcome =>
      'AI旅行コンシェルジュが、$parkNameでの希望を順番に整理します。',
    GuidedPlanningStep.mainFocus => '今日は何を一番楽しみたいですか？',
    GuidedPlanningStep.focusDetail => _focusDetailQuestion,
    GuidedPlanningStep.secondaryExperience => _secondaryQuestion,
    GuidedPlanningStep.foodStyle => 'フードや休憩は、どのように楽しみたいですか？',
    GuidedPlanningStep.freeDrinkPreference =>
      'フリードリンク特典をどのように活用しますか？',
    GuidedPlanningStep.characterInterest => 'キャラクターグリーティングはどうしますか？',
    GuidedPlanningStep.seasonalPreference => '季節限定の体験はどの程度入れたいですか？',
    GuidedPlanningStep.completed => '$parkNameでの希望を確認してください。',
  };

  String get _focusDetailQuestion => switch (primaryFocus) {
    GuidedPlanningFocus.attractions => 'どんなアトラクションを優先したいですか？',
    GuidedPlanningFocus.entertainment => 'どんなショー・パレードを優先したいですか？',
    GuidedPlanningFocus.characters => 'キャラクター体験で何を重視しますか？',
    GuidedPlanningFocus.food => 'フード・ドリンクで何を重視しますか？',
    GuidedPlanningFocus.balanced => 'バランスの中でも、少し多めに入れたいものはありますか？',
    GuidedPlanningFocus.aiChoice => 'AIがおすすめを選ぶとき、避けたい傾向はありますか？',
    null => '好みをもう少し教えてください。',
  };

  String get _secondaryQuestion => switch (primaryFocus) {
    GuidedPlanningFocus.attractions => 'ショー・パレードも見たいですか？',
    GuidedPlanningFocus.entertainment => 'アトラクションはどの程度入れたいですか？',
    GuidedPlanningFocus.characters => 'アトラクションやショーも入れますか？',
    GuidedPlanningFocus.food => 'アトラクションやショーも楽しみますか？',
    GuidedPlanningFocus.balanced ||
    GuidedPlanningFocus.aiChoice ||
    null => 'アトラクションとショーの配分はどうしますか？',
  };

  String get selectionGuide => switch (step) {
    GuidedPlanningStep.welcome => '約1〜2分です。回答は後から変更できます。',
    GuidedPlanningStep.completed => '',
    _ => '${options.length}つから1つ選択してください。',
  };

  String get aiNote => switch (step) {
    GuidedPlanningStep.welcome => '施設名を知らなくても大丈夫です。大きな希望から少しずつ絞ります。',
    GuidedPlanningStep.mainFocus => '最初の回答に合わせて、次の質問内容を変えます。',
    GuidedPlanningStep.focusDetail => '選んだ主目的を、好みの方向へ絞り込みます。',
    GuidedPlanningStep.secondaryExperience => '主目的以外の体験を、どの程度含めるか調整します。',
    GuidedPlanningStep.foodStyle => '食事時間と短い休憩の候補へ反映します。',
    GuidedPlanningStep.freeDrinkPreference =>
      '特典対象として確認されたメニューだけを専用候補へ反映します。',
    GuidedPlanningStep.characterInterest => 'グリーティング候補の優先度へ反映します。',
    GuidedPlanningStep.seasonalPreference => '期間限定メニューや公演の扱いを調整します。',
    GuidedPlanningStep.completed => '候補確認画面で追加・削除・優先度変更ができます。',
  };

  List<String> get options => switch (step) {
    GuidedPlanningStep.welcome => const ['AI質問を始める'],
    GuidedPlanningStep.mainFocus => const [
      'アトラクション',
      'ショー・パレード',
      'キャラクター',
      'フード・ドリンク',
      'バランスよく',
      'AIにおまかせ',
    ],
    GuidedPlanningStep.focusDetail => _focusDetailOptions,
    GuidedPlanningStep.secondaryExperience => _secondaryOptions,
    GuidedPlanningStep.foodStyle => const [
      'レストランでしっかり',
      '食べ歩き中心',
      '季節限定を優先',
      '休憩として少し',
      '最低限でよい',
      'AIにおまかせ',
    ],
    GuidedPlanningStep.freeDrinkPreference => const [
      '積極的に活用したい',
      '休憩時に使いたい',
      '対象の限定ドリンクを優先',
      '特に重視しない',
      'AIにおまかせ',
    ],
    GuidedPlanningStep.characterInterest => const [
      '優先したい',
      '時間が合えば',
      '今回は重視しない',
      'AIにおまかせ',
    ],
    GuidedPlanningStep.seasonalPreference => const [
      '積極的に入れたい',
      '時間が合えば',
      'フードだけ',
      'ショーだけ',
      '今回は重視しない',
      'AIにおまかせ',
    ],
    GuidedPlanningStep.completed => const [],
  };

  List<String> get _focusDetailOptions => switch (primaryFocus) {
    GuidedPlanningFocus.attractions => const [
      'スリル・絶叫',
      '物語・世界観',
      'キャラクター',
      'ゆったり楽しめるもの',
      '人気施設を中心に',
      'AIにおまかせ',
    ],
    GuidedPlanningFocus.entertainment => const [
      'パレード',
      '屋内ショー',
      '季節イベント',
      '夜のショー',
      'キャラクター中心',
      'AIにおまかせ',
    ],
    GuidedPlanningFocus.characters => const [
      'グリーティング',
      'キャラクターのショー',
      'キャラクター系アトラクション',
      '写真を楽しみたい',
      'AIにおまかせ',
    ],
    GuidedPlanningFocus.food => const [
      '季節限定メニュー',
      '食べ歩き',
      'レストラン',
      'ドリンク・スイーツ',
      'AIにおまかせ',
    ],
    GuidedPlanningFocus.balanced => const [
      'アトラクションを少し多め',
      'ショーを少し多め',
      'フードを少し多め',
      'キャラクターを少し多め',
      '完全にバランス',
    ],
    GuidedPlanningFocus.aiChoice => const [
      '激しい乗り物は控えめ',
      '長い待ち時間は控えめ',
      '屋外中心は控えめ',
      '特にない',
    ],
    null => const ['AIにおまかせ'],
  };

  List<String> get _secondaryOptions => switch (primaryFocus) {
    GuidedPlanningFocus.attractions => const [
      'ぜひ見たい',
      '時間が合えば',
      '1つだけ',
      '今回は重視しない',
    ],
    GuidedPlanningFocus.entertainment => const [
      '人気施設を少し',
      '待ち時間が短いもの',
      'できるだけ多く',
      'ほとんど不要',
    ],
    GuidedPlanningFocus.characters => const [
      '両方入れたい',
      'アトラクション中心',
      'ショー中心',
      'キャラクター中心でよい',
    ],
    GuidedPlanningFocus.food => const [
      '両方入れたい',
      'アトラクションを少し',
      'ショーを少し',
      'フード中心でよい',
    ],
    GuidedPlanningFocus.balanced ||
    GuidedPlanningFocus.aiChoice ||
    null => const [
      '両方バランスよく',
      'アトラクション多め',
      'ショー多め',
      '待ち時間が短い方を優先',
    ],
  };

  String optionDescription(String option) => switch (option) {
    'AI質問を始める' => '大きな希望から順番に絞り込みます',
    'アトラクション' => '乗り物を中心に一日の満足度を高める',
    'ショー・パレード' => '公演時刻を軸に一日の流れを組み立てる',
    'キャラクター' => '会う・見る・写真を撮る体験を優先',
    'フード・ドリンク' => '食事・限定メニュー・休憩を重視',
    'バランスよく' => '複数カテゴリを無理なく組み合わせる',
    'AIにおまかせ' => '混雑や移動を見てAIが配分する',
    'スリル・絶叫' => '刺激の強いアトラクションを優先',
    '物語・世界観' => '演出や没入感を重視',
    'ゆったり楽しめるもの' => '負担が少ない体験を中心にする',
    '人気施設を中心に' => '代表的な人気施設を優先',
    'パレード' => 'パレードを優先候補にする',
    '屋内ショー' => '座って楽しめる公演を優先',
    '季節イベント' => '期間限定の公演を優先',
    '夜のショー' => '夕方以降の公演を軸にする',
    'グリーティング' => 'キャラクターに会う時間を確保',
    '食べ歩き' => '短時間で楽しめる軽食を候補化',
    'レストラン' => '着席して食べる時間を確保',
    'ドリンク・スイーツ' => '休憩しやすいメニューを候補化',
    '積極的に活用したい' => '特典対象メニューを複数回の休憩候補へ入れる',
    '休憩時に使いたい' => '移動の途中で利用しやすい対象メニューを入れる',
    '対象の限定ドリンクを優先' => '特典対象の限定メニューを優先する',
    '特に重視しない' => 'フリードリンク候補を自動追加しない',
    'ぜひ見たい' => 'ショーを優先候補として扱う',
    '時間が合えば' => '主目的を妨げない範囲で追加',
    '今回は重視しない' => '候補数を抑える',
    'レストランでしっかり' => '食事時間を固定枠として確保',
    '季節限定を優先' => '期間限定フードやドリンクを優先',
    '休憩として少し' => '短い休憩候補だけ追加',
    '最低限でよい' => '食事以外の体験を優先',
    '優先したい' => 'グリーティングを候補へ追加',
    '積極的に入れたい' => '季節限定の公演とメニューを優先',
    'フードだけ' => '季節限定メニューだけを優先',
    'ショーだけ' => '季節限定公演だけを優先',
    _ => '',
  };

  IconData optionIcon(String option) => switch (option) {
    'AI質問を始める' || 'AIにおまかせ' => Icons.auto_awesome_rounded,
    'アトラクション' ||
    'スリル・絶叫' ||
    '物語・世界観' ||
    '人気施設を中心に' => Icons.attractions_rounded,
    'ショー・パレード' ||
    'パレード' ||
    '屋内ショー' ||
    '夜のショー' => Icons.theater_comedy_rounded,
    'キャラクター' ||
    'グリーティング' ||
    'キャラクター中心' => Icons.face_rounded,
    'フード・ドリンク' ||
    '食べ歩き' ||
    'レストラン' ||
    'レストランでしっかり' => Icons.restaurant_rounded,
    'ドリンク・スイーツ' ||
    'フリードリンク活用' => Icons.local_drink_rounded,
    '季節イベント' ||
    '季節限定を優先' ||
    '積極的に入れたい' => Icons.celebration_rounded,
    'バランスよく' ||
    '完全にバランス' ||
    '両方バランスよく' => Icons.balance_rounded,
    '時間が合えば' || '休憩として少し' => Icons.schedule_rounded,
    '今回は重視しない' ||
    '最低限でよい' ||
    'ほとんど不要' => Icons.remove_circle_outline_rounded,
    _ => Icons.check_circle_outline_rounded,
  };

  bool get isMultiSelectStep => false;
  bool get isFoodStep => step == GuidedPlanningStep.foodStyle;
  bool get canGoBack => step != GuidedPlanningStep.welcome;

  List<GuidedPlanningStep> get _steps => [
    GuidedPlanningStep.welcome,
    GuidedPlanningStep.mainFocus,
    GuidedPlanningStep.focusDetail,
    GuidedPlanningStep.secondaryExperience,
    GuidedPlanningStep.foodStyle,
    if (hasFreeDrinkBenefit) GuidedPlanningStep.freeDrinkPreference,
    GuidedPlanningStep.characterInterest,
    GuidedPlanningStep.seasonalPreference,
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
        _setPrimaryFocus(answer);
        step = GuidedPlanningStep.focusDetail;
      case GuidedPlanningStep.focusDetail:
        focusDetailAnswer = answer;
        _applyFocusDetail(answer);
        step = GuidedPlanningStep.secondaryExperience;
      case GuidedPlanningStep.secondaryExperience:
        secondaryExperienceAnswer = answer;
        _applySecondaryExperience(answer);
        step = GuidedPlanningStep.foodStyle;
      case GuidedPlanningStep.foodStyle:
        foodStyleAnswer = answer;
        _applyFoodStyle(answer);
        step = hasFreeDrinkBenefit
            ? GuidedPlanningStep.freeDrinkPreference
            : GuidedPlanningStep.characterInterest;
      case GuidedPlanningStep.freeDrinkPreference:
        freeDrinkPreferenceAnswer = answer;
        _applyFreeDrinkPreference(answer);
        step = GuidedPlanningStep.characterInterest;
      case GuidedPlanningStep.characterInterest:
        characterInterestAnswer = answer;
        _applyCharacterInterest(answer);
        step = GuidedPlanningStep.seasonalPreference;
      case GuidedPlanningStep.seasonalPreference:
        seasonalPreferenceAnswer = answer;
        _applySeasonalPreference(answer);
        step = GuidedPlanningStep.completed;
      case GuidedPlanningStep.completed:
        break;
    }
    notifyListeners();
  }

  void confirmCurrentMultiSelection() {}

  void confirmFoodSelection() {}

  void _setPrimaryFocus(String answer) {
    _clearAnswersAfterMainFocus();
    primaryFocus = switch (answer) {
      'アトラクション' => GuidedPlanningFocus.attractions,
      'ショー・パレード' => GuidedPlanningFocus.entertainment,
      'キャラクター' => GuidedPlanningFocus.characters,
      'フード・ドリンク' => GuidedPlanningFocus.food,
      'バランスよく' => GuidedPlanningFocus.balanced,
      _ => GuidedPlanningFocus.aiChoice,
    };

    wantsAttractions = primaryFocus == GuidedPlanningFocus.attractions;
    wantsEntertainment = primaryFocus == GuidedPlanningFocus.entertainment;
    wantsBalancedPlan =
        primaryFocus == GuidedPlanningFocus.balanced ||
        primaryFocus == GuidedPlanningFocus.aiChoice;

    if (primaryFocus == GuidedPlanningFocus.characters) {
      preferredCategories.add(WishItemCategory.greeting);
    }
    if (primaryFocus == GuidedPlanningFocus.food) {
      preferredCategories.addAll({
        WishItemCategory.food,
        WishItemCategory.specialDrink,
      });
    }
    if (wantsBalancedPlan) {
      wantsAttractions = true;
      wantsEntertainment = true;
    }
  }

  void _applyFocusDetail(String answer) {
    switch (primaryFocus) {
      case GuidedPlanningFocus.attractions:
        wantsAttractions = true;
      case GuidedPlanningFocus.entertainment:
        wantsEntertainment = true;
        if (answer == '季節イベント') {
          wantsSeasonalEntertainment = true;
        }
      case GuidedPlanningFocus.characters:
        preferredCategories.add(WishItemCategory.greeting);
        if (answer == 'キャラクターのショー') {
          wantsEntertainment = true;
        } else if (answer == 'キャラクター系アトラクション') {
          wantsAttractions = true;
        }
      case GuidedPlanningFocus.food:
        _applyFoodFocusDetail(answer);
      case GuidedPlanningFocus.balanced:
        wantsBalancedPlan = true;
        wantsAttractions = true;
        wantsEntertainment = true;
        if (answer == 'フードを少し多め') {
          preferredCategories.add(WishItemCategory.food);
        } else if (answer == 'キャラクターを少し多め') {
          preferredCategories.add(WishItemCategory.greeting);
        }
      case GuidedPlanningFocus.aiChoice:
        wantsBalancedPlan = true;
        wantsAttractions = true;
        wantsEntertainment = true;
      case null:
        break;
    }
  }

  void _applyFoodFocusDetail(String answer) {
    if (answer == '季節限定メニュー') {
      wantsSeasonalMenus = true;
      preferredCategories.addAll({
        WishItemCategory.food,
        WishItemCategory.specialDrink,
        WishItemCategory.dessert,
      });
    } else if (answer == '食べ歩き') {
      preferredCategories.addAll({
        WishItemCategory.snack,
        WishItemCategory.food,
      });
    } else if (answer == 'レストラン') {
      preferredCategories.add(WishItemCategory.food);
    } else if (answer == 'ドリンク・スイーツ') {
      preferredCategories.addAll({
        WishItemCategory.specialDrink,
        WishItemCategory.cafeDrink,
        WishItemCategory.dessert,
      });
    }
  }

  void _applySecondaryExperience(String answer) {
    if (primaryFocus == GuidedPlanningFocus.attractions) {
      wantsEntertainment = answer != '今回は重視しない';
    } else if (primaryFocus == GuidedPlanningFocus.entertainment) {
      wantsAttractions = answer != 'ほとんど不要';
    } else if (answer == 'アトラクション中心' ||
        answer == 'アトラクションを少し' ||
        answer == 'アトラクション多め') {
      wantsAttractions = true;
    } else if (answer == 'ショー中心' ||
        answer == 'ショーを少し' ||
        answer == 'ショー多め') {
      wantsEntertainment = true;
    } else if (answer.contains('両方') ||
        answer == '待ち時間が短い方を優先') {
      wantsAttractions = true;
      wantsEntertainment = true;
    }
  }

  void _applyFoodStyle(String answer) {
    preferredCategories.removeAll(_foodCategories);
    wantsSeasonalMenus = false;

    if (answer == 'レストランでしっかり') {
      preferredCategories.add(WishItemCategory.food);
    } else if (answer == '食べ歩き中心') {
      preferredCategories.addAll({
        WishItemCategory.food,
        WishItemCategory.snack,
        WishItemCategory.dessert,
      });
    } else if (answer == '季節限定を優先') {
      wantsSeasonalMenus = true;
      preferredCategories.addAll({
        WishItemCategory.food,
        WishItemCategory.specialDrink,
        WishItemCategory.dessert,
      });
    } else if (answer == '休憩として少し') {
      preferredCategories.addAll({
        WishItemCategory.cafeDrink,
        WishItemCategory.juice,
        WishItemCategory.dessert,
      });
    } else if (answer == 'AIにおまかせ') {
      preferredCategories.addAll({
        WishItemCategory.food,
        WishItemCategory.specialDrink,
      });
    }
  }

  void _applyFreeDrinkPreference(String answer) {
    wantsFeaturedFreeDrinkMenus =
        hasFreeDrinkBenefit && answer != '特に重視しない';
  }

  void _applyCharacterInterest(String answer) {
    preferredCategories.remove(WishItemCategory.greeting);
    if (answer == '優先したい' || answer == '時間が合えば') {
      preferredCategories.add(WishItemCategory.greeting);
    } else if (answer == 'AIにおまかせ' && wantsBalancedPlan) {
      preferredCategories.add(WishItemCategory.greeting);
    }
  }

  void _applySeasonalPreference(String answer) {
    wantsSeasonalMenus = false;
    wantsSeasonalEntertainment = false;
    wantsSeasonalGoods = false;

    if (answer == '積極的に入れたい' || answer == 'AIにおまかせ') {
      wantsSeasonalMenus = true;
      wantsSeasonalEntertainment = true;
    } else if (answer == '時間が合えば') {
      wantsSeasonalEntertainment = true;
    } else if (answer == 'フードだけ') {
      wantsSeasonalMenus = true;
    } else if (answer == 'ショーだけ') {
      wantsSeasonalEntertainment = true;
    }
  }

  bool isOptionSelected(String option) => false;

  void goBack() {
    if (step == GuidedPlanningStep.completed) {
      step = _steps.last;
    } else {
      final index = _steps.indexOf(step);
      if (index > 0) {
        step = _steps[index - 1];
      }
    }
    notifyListeners();
  }

  Future<int> applyToWishListWithDynamicScoring(List<WishItem> items) async {
    final parkId = appState.tripSettings.parkId;
    final date = appState.tripSettings.visitDate ?? DateTime.now();
    final parkItems = items.where((item) => item.parkId == parkId && item.isAvailableOn(date)).toList(growable: false);
    final facilities = await ServiceLocator.facilityRepository.getFacilitiesByParkId(parkId);
    final operationalById = <String, Facility>{for (final f in facilities) if (f.canAddToPlanAt(date)) f.id: f};
    final profiles = await const CrowdFactorRepositoryImpl().loadWaitProfiles(parkId: parkId);
    const waitScorer = DynamicWaitScoringService();

    double activeContentValue(WishItem item) {
      var score = 0.0;
      if (item.eventPackId != 'facility_master') score += 18;
      score += switch (item.category) {
        WishItemCategory.specialDrink => 20,
        WishItemCategory.drinkJelly => 18,
        WishItemCategory.goods => 20,
        WishItemCategory.souvenir => 18,
        WishItemCategory.food => 14,
        WishItemCategory.dessert => 14,
        WishItemCategory.snack => 12,
        WishItemCategory.entertainment => 16,
        _ => 0,
      };
      if (item.freeDrinkEligible && hasFreeDrinkBenefit) score += 10;
      final daysRemaining = item.endDate.difference(date).inDays;
      if (daysRemaining >= 0 && daysRemaining <= 14) {
        score += 12;
      } else if (daysRemaining >= 0 && daysRemaining <= 30) {
        score += 6;
      }
      return score;
    }

    final contentBoostByFacility = <String, double>{};
    for (final content in parkItems) {
      final value = activeContentValue(content);
      if (value <= 0) continue;
      for (final facilityId in content.venueFacilityIds) {
        if (!operationalById.containsKey(facilityId)) continue;
        contentBoostByFacility[facilityId] =
            (contentBoostByFacility[facilityId] ?? 0) + value;
      }
    }

    double attractionScore(WishItem item) {
      final venues = item.venueFacilityIds
          .map((id) => operationalById[id])
          .whereType<Facility>()
          .where((f) => f.category == FacilityCategory.attraction);
      var best = double.negativeInfinity;
      for (final facility in venues) {
        final wait = waitScorer.evaluate(
          facilityId: facility.id,
          profiles: profiles,
          facilityCurrentWaitMinutes: facility.waitTime?.minutes,
        );
        final priority = facility.priority.value;
        final baseExperienceValue = switch (priority) {
          >= 5 => 40.0,
          4 => 20.0,
          3 => 10.0,
          2 => 5.0,
          _ => 0.0,
        };
        var score = wait.savingMinutes.toDouble() + baseExperienceValue;
        score += contentBoostByFacility[facility.id] ?? 0;
        if (facility.isSeasonal) score += 12;
        if (appState.tripSettings.hasHappyEntry &&
            wait.savingMinutes > 0) {
          score += 8;
        }
        if (facility.supportsDpa && !wait.usedFallback) score -= 12;
        if (score > best) best = score;
      }
      return best;
    }

    double wishContentScore(WishItem item) {
      var score = activeContentValue(item);
      for (final facilityId in item.venueFacilityIds) {
        score += (contentBoostByFacility[facilityId] ?? 0) * 0.25;
      }
      return score;
    }

    final selected = <String>{};

    void addLimited(
      bool Function(WishItem item) test,
      int limit, {
      bool rankAttractions = false,
      bool rankActiveContent = false,
    }) {
      var candidates = parkItems.where(test).toList(growable: false);
      if (rankAttractions) {
        candidates = [...candidates]
          ..sort((a, b) => attractionScore(b).compareTo(attractionScore(a)));
      } else if (rankActiveContent) {
        candidates = [...candidates]
          ..sort((a, b) => wishContentScore(b).compareTo(wishContentScore(a)));
      }
      selected.addAll(candidates.take(limit).map((item) => item.id));
    }

    if (wantsAttractions) addLimited((item) => item.category == WishItemCategory.attraction, primaryFocus == GuidedPlanningFocus.attractions ? 8 : 5, rankAttractions: true);
    if (wantsEntertainment) {
      addLimited(
        (item) =>
            item.category == WishItemCategory.entertainment &&
            (!wantsSeasonalEntertainment ||
                item.eventPackId != 'facility_master'),
        primaryFocus == GuidedPlanningFocus.entertainment ? 4 : 2,
        rankActiveContent: true,
      );
    }
    if (preferredCategories.contains(WishItemCategory.greeting)) addLimited((item) => item.category == WishItemCategory.greeting, primaryFocus == GuidedPlanningFocus.characters ? 3 : 1);
    final foodCategories = preferredCategories.intersection(_foodCategories);
    if (foodCategories.isNotEmpty || wantsSeasonalMenus) {
      addLimited(
        (item) {
          if (hasFreeDrinkBenefit && item.freeDrinkEligible) return false;
          return foodCategories.contains(item.category) ||
              (wantsSeasonalMenus &&
                  _foodCategories.contains(item.category) &&
                  item.eventPackId != 'facility_master');
        },
        primaryFocus == GuidedPlanningFocus.food ? 8 : 4,
        rankActiveContent: true,
      );
    }
    if (hasFreeDrinkBenefit && wantsFeaturedFreeDrinkMenus) {
      addLimited(
        (item) => item.freeDrinkEligible,
        freeDrinkPreferenceAnswer == '積極的に活用したい' ? 5 : 3,
        rankActiveContent: true,
      );
    }
    if (wantsSeasonalGoods) {
      addLimited(
        (item) =>
            item.category == WishItemCategory.goods ||
            item.category == WishItemCategory.souvenir,
        4,
        rankActiveContent: true,
      );
    }
    appState.clearWishSelection();
    appState.selectWishItems(selected);
    return selected.length;
  }

  int applyToWishList(List<WishItem> items) {
    final parkItems = items
        .where((item) => item.parkId == appState.tripSettings.parkId)
        .toList(growable: false);

    final selected = <String>{};

    void addLimited(
      bool Function(WishItem item) test,
      int limit,
    ) {
      selected.addAll(
        parkItems.where(test).map((item) => item.id).take(limit),
      );
    }

    if (wantsAttractions) {
      addLimited(
        (item) => item.category == WishItemCategory.attraction,
        primaryFocus == GuidedPlanningFocus.attractions ? 8 : 5,
      );
    }

    if (wantsEntertainment) {
      addLimited(
        (item) =>
            item.category == WishItemCategory.entertainment &&
            (!wantsSeasonalEntertainment ||
                item.eventPackId != 'facility_master'),
        primaryFocus == GuidedPlanningFocus.entertainment ? 4 : 2,
      );
    }

    if (preferredCategories.contains(WishItemCategory.greeting)) {
      addLimited(
        (item) => item.category == WishItemCategory.greeting,
        primaryFocus == GuidedPlanningFocus.characters ? 3 : 1,
      );
    }

    final foodCategories = preferredCategories.intersection(_foodCategories);
    if (foodCategories.isNotEmpty || wantsSeasonalMenus) {
      addLimited(
        (item) {
          if (hasFreeDrinkBenefit && item.freeDrinkEligible) {
            return false;
          }
          return foodCategories.contains(item.category) ||
              (wantsSeasonalMenus &&
                  _foodCategories.contains(item.category) &&
                  item.eventPackId != 'facility_master');
        },
        primaryFocus == GuidedPlanningFocus.food ? 8 : 4,
      );
    }

    if (hasFreeDrinkBenefit && wantsFeaturedFreeDrinkMenus) {
      addLimited(
        (item) => item.freeDrinkEligible,
        freeDrinkPreferenceAnswer == '積極的に活用したい' ? 5 : 3,
      );
    }

    appState.clearWishSelection();
    appState.selectWishItems(selected);
    return selected.length;
  }

  List<String> get summaryItems {
    final items = <String>[];

    if (primaryFocus != null) {
      items.add('最優先：${_focusLabel(primaryFocus!)}');
    }
    if (focusDetailAnswer != null) {
      items.add('好み：$focusDetailAnswer');
    }
    if (secondaryExperienceAnswer != null) {
      items.add('他の体験：$secondaryExperienceAnswer');
    }
    if (foodStyleAnswer != null) {
      items.add('フード：$foodStyleAnswer');
    }
    if (hasFreeDrinkBenefit && freeDrinkPreferenceAnswer != null) {
      items.add('フリードリンク：$freeDrinkPreferenceAnswer');
    }
    if (characterInterestAnswer != null) {
      items.add('キャラクター：$characterInterestAnswer');
    }
    if (seasonalPreferenceAnswer != null) {
      items.add('季節限定：$seasonalPreferenceAnswer');
    }
    if (usesVacationPackage) {
      items.add('バケーションパッケージ設定を反映');
    }
    return items;
  }

  String _focusLabel(GuidedPlanningFocus focus) => switch (focus) {
    GuidedPlanningFocus.attractions => 'アトラクション',
    GuidedPlanningFocus.entertainment => 'ショー・パレード',
    GuidedPlanningFocus.characters => 'キャラクター',
    GuidedPlanningFocus.food => 'フード・ドリンク',
    GuidedPlanningFocus.balanced => 'バランス',
    GuidedPlanningFocus.aiChoice => 'AIおまかせ',
  };

  String get summary {
    final parts = <String>['対象パーク：$parkName', ...summaryItems];
    return '今回の希望\n\n・${parts.join('\n・')}';
  }

  void applyDebugPreset(GuidedPlanningDebugPreset preset) {
    restart(clearWishSelection: false);

    switch (preset) {
      case GuidedPlanningDebugPreset.attractionThrill:
        _runDebugAnswers([
          'アトラクション',
          'スリル・絶叫',
          '時間が合えば',
          '食べ歩き中心',
          '今回は重視しない',
          '時間が合えば',
        ]);
      case GuidedPlanningDebugPreset.attractionStory:
        _runDebugAnswers([
          'アトラクション',
          '物語・世界観',
          'ぜひ見たい',
          '季節限定を優先',
          '時間が合えば',
          '積極的に入れたい',
        ]);
      case GuidedPlanningDebugPreset.entertainment:
        _runDebugAnswers([
          'ショー・パレード',
          '夜のショー',
          '人気施設を少し',
          'レストランでしっかり',
          '時間が合えば',
          'ショーだけ',
        ]);
      case GuidedPlanningDebugPreset.seasonalFood:
        _runDebugAnswers([
          'フード・ドリンク',
          '季節限定メニュー',
          'ショーを少し',
          '季節限定を優先',
          '今回は重視しない',
          '積極的に入れたい',
        ]);
      case GuidedPlanningDebugPreset.characters:
        _runDebugAnswers([
          'キャラクター',
          'グリーティング',
          '両方入れたい',
          '休憩として少し',
          '優先したい',
          '時間が合えば',
        ]);
      case GuidedPlanningDebugPreset.balanced:
        _runDebugAnswers([
          'バランスよく',
          '完全にバランス',
          '両方バランスよく',
          'AIにおまかせ',
          '時間が合えば',
          'AIにおまかせ',
        ]);
      case GuidedPlanningDebugPreset.aiChoice:
        _runDebugAnswers([
          'AIにおまかせ',
          '特にない',
          '待ち時間が短い方を優先',
          'AIにおまかせ',
          'AIにおまかせ',
          'AIにおまかせ',
        ]);
      case GuidedPlanningDebugPreset.allIn:
        _runDebugAnswers([
          'バランスよく',
          '完全にバランス',
          '両方バランスよく',
          '季節限定を優先',
          '優先したい',
          '積極的に入れたい',
        ]);
    }

    notifyListeners();
  }

  void _runDebugAnswers(List<String> answers) {
    step = GuidedPlanningStep.mainFocus;
    for (var index = 0; index < answers.length; index++) {
      answerWithoutNotify(answers[index]);
      if (index == 3 &&
          step == GuidedPlanningStep.freeDrinkPreference) {
        answerWithoutNotify('AIにおまかせ');
      }
    }
  }

  void answerWithoutNotify(String value) {
    switch (step) {
      case GuidedPlanningStep.welcome:
        step = GuidedPlanningStep.mainFocus;
      case GuidedPlanningStep.mainFocus:
        _setPrimaryFocus(value);
        step = GuidedPlanningStep.focusDetail;
      case GuidedPlanningStep.focusDetail:
        focusDetailAnswer = value;
        _applyFocusDetail(value);
        step = GuidedPlanningStep.secondaryExperience;
      case GuidedPlanningStep.secondaryExperience:
        secondaryExperienceAnswer = value;
        _applySecondaryExperience(value);
        step = GuidedPlanningStep.foodStyle;
      case GuidedPlanningStep.foodStyle:
        foodStyleAnswer = value;
        _applyFoodStyle(value);
        step = hasFreeDrinkBenefit
            ? GuidedPlanningStep.freeDrinkPreference
            : GuidedPlanningStep.characterInterest;
      case GuidedPlanningStep.freeDrinkPreference:
        freeDrinkPreferenceAnswer = value;
        _applyFreeDrinkPreference(value);
        step = GuidedPlanningStep.characterInterest;
      case GuidedPlanningStep.characterInterest:
        characterInterestAnswer = value;
        _applyCharacterInterest(value);
        step = GuidedPlanningStep.seasonalPreference;
      case GuidedPlanningStep.seasonalPreference:
        seasonalPreferenceAnswer = value;
        _applySeasonalPreference(value);
        step = GuidedPlanningStep.completed;
      case GuidedPlanningStep.completed:
        break;
    }
  }

  void restart({bool clearWishSelection = false}) {
    step = GuidedPlanningStep.welcome;
    primaryFocus = null;
    focusDetailAnswer = null;
    secondaryExperienceAnswer = null;
    foodStyleAnswer = null;
    freeDrinkPreferenceAnswer = null;
    characterInterestAnswer = null;
    seasonalPreferenceAnswer = null;
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

  void _clearAnswersAfterMainFocus() {
    focusDetailAnswer = null;
    secondaryExperienceAnswer = null;
    foodStyleAnswer = null;
    freeDrinkPreferenceAnswer = null;
    characterInterestAnswer = null;
    seasonalPreferenceAnswer = null;
    preferredCategories.clear();
    wantsFeaturedFreeDrinkMenus = false;
    wantsEntertainment = false;
    wantsAttractions = false;
    wantsBalancedPlan = false;
    wantsSeasonalMenus = false;
    wantsSeasonalEntertainment = false;
    wantsSeasonalGoods = false;
  }

  void _restorePackageSettings() {
    usesVacationPackage = appState.tripSettings.usesVacationPackage;
    usesFreeDrink =
        usesVacationPackage && appState.tripSettings.usesFreeDrinkBenefit;
  }

  static const Set<WishItemCategory> _foodCategories = {
    WishItemCategory.specialDrink,
    WishItemCategory.cafeDrink,
    WishItemCategory.juice,
    WishItemCategory.soup,
    WishItemCategory.drinkJelly,
    WishItemCategory.food,
    WishItemCategory.dessert,
    WishItemCategory.snack,
  };
}
