// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import

import 'package:bivium/main.dart';

void main() {
  setUpAll(() {
    // Initialize SharedPreferences with a mock for testing
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App builds smoke test', (WidgetTester tester) async {
    // Pass the mock SharedPreferences instance to BiviumApp
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(BiviumApp(prefs: prefs));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
