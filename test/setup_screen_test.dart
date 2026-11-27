import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swiftmart_frontend/main.dart';

void main() {
  testWidgets('first launch requires a valid server address', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Connect to SwiftMart'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'not-a-server');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter an HTTP or HTTPS server address'),
        findsOneWidget);
    expect(find.text('Connect to SwiftMart'), findsOneWidget);
  });
}
