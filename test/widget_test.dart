import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patients/main.dart';

void main() {
  testWidgets('App boots (smoke test)', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Let the splash screen's delayed navigation complete.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
