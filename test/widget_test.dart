import 'package:disney_planner/app/disney_planner_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Disney Planner app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const DisneyPlannerApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
