import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patients/main.dart';

void main() {
  testWidgets('MyApp builds MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    // SplashScreen schedules navigation after 3.5s — advance fake async so the test can finish.
    await tester.pump(const Duration(seconds: 4));
  });
}
