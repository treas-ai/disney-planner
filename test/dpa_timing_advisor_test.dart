import 'package:flutter_test/flutter_test.dart';
import 'package:disney_planner/domain/services/dpa_timing_advisor.dart';

void main() {
  const advisor = DpaTimingAdvisor();

  test('DPA 1時間枠の全10分候補が塞がる場合は非推奨', () {
    final rating = advisor.rateStart(
      startMinutes: 16 * 60,
      blockedWindows: const [
        DpaBlockedWindow(startMinutes: 16 * 60, endMinutes: 17 * 60),
      ],
    );

    expect(rating, DpaTimingRating.avoid);
  });

  test('DPA 1時間枠に10分候補が少しだけ残る場合は注意', () {
    final rating = advisor.rateStart(
      startMinutes: 15 * 60 + 30,
      blockedWindows: const [
        DpaBlockedWindow(startMinutes: 15 * 60 + 50, endMinutes: 17 * 60),
      ],
    );

    expect(rating, DpaTimingRating.caution);
  });

  test('DPA 1時間枠に十分な利用開始余地があればおすすめ', () {
    final rating = advisor.rateStart(
      startMinutes: 14 * 60,
      blockedWindows: const [
        DpaBlockedWindow(startMinutes: 16 * 60, endMinutes: 17 * 60),
      ],
    );

    expect(rating, DpaTimingRating.good);
  });

  test('10分刻みの同評価区間をまとめる', () {
    final ranges = advisor.buildRanges(
      startMinutes: 15 * 60,
      endMinutes: 16 * 60,
      blockedWindows: const [
        DpaBlockedWindow(startMinutes: 16 * 60, endMinutes: 17 * 60),
      ],
    );

    expect(ranges, isNotEmpty);
    expect(ranges.last.endMinutes, 16 * 60);
  });
}
