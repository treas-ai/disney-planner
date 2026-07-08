import 'package:flutter_test/flutter_test.dart';
import 'package:disney_planner/app/disney_planner_app.dart';

void main() {
  testWidgets('Disney Planner app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const DisneyPlannerApp());

    expect(find.text('Disney Planner'), findsOneWidget);
    expect(find.text('Version 0.2'), findsOneWidget);
  });
}