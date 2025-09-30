// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:kidsync/main.dart';

void main() {
  testWidgets('App initialization test', (WidgetTester tester) async {
    // On mobile, initialUrl will be empty string
    final initialUrlFromMain = kIsWeb ? "" : "";

    // Build our app and trigger a frame.
    await tester.pumpWidget(KidSyncApp(initialUrl: initialUrlFromMain));

    // Verify that app loads with initial loading screen
    expect(find.text('Initializing... Please wait.'), findsOneWidget);
  });
}
