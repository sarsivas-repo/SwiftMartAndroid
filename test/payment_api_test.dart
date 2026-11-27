import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftmart_frontend/services/api_service.dart';

void main() {
  test('connected payment includes native Android device context', () async {
    ApiService.configureServer('https://example.test/api');
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['device'], 'mobile');
      expect(body['os'], 'android');
      expect(body['rendering_type'], 'native');
      return http.Response(
        '{"payment":{"id":"example","provider":"cashfree",'
        '"state":"ready","amount_paise":100}}',
        200,
      );
    });
    await http.runWithClient(() async {
      final payment = await ApiService.createSandboxPayment(
        draftId: '1',
        provider: 'cashfree',
        taxPaise: 0,
        customerPhone: '9876543210',
        os: 'others',
        browser: 'others',
      );
      expect(payment.id, 'example');
    }, () => client);
  });
}
