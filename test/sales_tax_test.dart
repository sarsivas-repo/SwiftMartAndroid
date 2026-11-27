import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftmart_frontend/providers/bill_provider.dart';
import 'package:swiftmart_frontend/services/api_service.dart';

void main() {
  setUp(() => ApiService.configureServer('https://example.test/api'));

  test('connected draft uses server totals and line snapshots', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode({
        'draft': {
          'id': 1, 'customer_id': null, 'pricing_version': 1,
          'subtotal': 200, 'tax': 23, 'total': 223,
          'items': [
            {'product_id': 3, 'product_name': 'Item', 'quantity': 1, 'price': 118,
              'subtotal': 118, 'line_total_minor': 11800,
              'tax_mode': 'inclusive', 'tax_basis_points': 1800, 'tax_minor': 1800},
            {'direct_item_id': 2, 'product_id': 0, 'product_name': 'Eggs',
              'quantity': 1, 'price': 100, 'subtotal': 100,
              'line_total_minor': 10500, 'tax_mode': 'additional',
              'tax_basis_points': 500, 'tax_minor': 500},
          ],
        },
      }), 201);
    });
    await http.runWithClient(() async {
      final bills = BillProvider();
      await bills.createNewBill('guest');
      expect(jsonDecode(requests.single.body)['pricing_version'], 1);
      expect(bills.currentSubtotal, 200);
      expect(bills.currentTax, 23);
      expect(bills.currentTotal, 223);
      expect(bills.currentBill!.items.last.subtotal, 105);
      expect(bills.currentBill!.items.last.taxDescription, '5.00% tax added');
    }, () => client);
  });

  test('old server cannot silently create a tax-aware bill', () async {
    final client = MockClient((_) async => http.Response('{"draft":{"id":1}}', 201));
    await http.runWithClient(() async {
      await expectLater(ApiService.createDraftBill(null), throwsStateError);
    }, () => client);
  });
}
