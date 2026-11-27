import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftmart_frontend/widgets/payment_settings.dart';

void main() {
  testWidgets('loads and saves the selected provider for the server',
      (tester) async {
    String? saved;
    final client = MockClient((request) async {
      if (request.method == 'PUT') {
        saved = (jsonDecode(request.body) as Map<String, dynamic>)['provider']
            as String;
        return http.Response('{}', 200);
      }
      return http.Response(
        '{"mode":"live","selected_provider":"razorpay","providers":'
        '[{"name":"razorpay","configured":true},'
        '{"name":"cashfree","configured":true},'
        '{"name":"phonepe","configured":false}]}',
        200,
      );
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: PaymentSettings()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Server environment: LIVE'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('phonepe'), findsNothing);
      await tester.tap(find.text('cashfree').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save payment provider'));
      await tester.pumpAndSettle();
      expect(saved, 'cashfree');
      expect(find.text('Payment provider saved.'), findsOneWidget);
    }, () => client);
  });
}
