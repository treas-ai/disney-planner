enum MealPreference {
  breakfast('朝食'),
  lunch('昼食'),
  dinner('夕食'),
  breakfastAndLunch('朝食・昼食'),
  lunchAndDinner('昼食・夕食'),
  breakfastLunchAndDinner('朝食・昼食・夕食'),
  flexible('空いている食事時間');

  const MealPreference(this.label);

  final String label;

  bool get includesBreakfast {
    return this == MealPreference.breakfast ||
        this == MealPreference.breakfastAndLunch ||
        this == MealPreference.breakfastLunchAndDinner;
  }

  bool get includesLunch {
    return this == MealPreference.lunch ||
        this == MealPreference.breakfastAndLunch ||
        this == MealPreference.lunchAndDinner ||
        this == MealPreference.breakfastLunchAndDinner;
  }

  bool get includesDinner {
    return this == MealPreference.dinner ||
        this == MealPreference.lunchAndDinner ||
        this == MealPreference.breakfastLunchAndDinner;
  }
}
