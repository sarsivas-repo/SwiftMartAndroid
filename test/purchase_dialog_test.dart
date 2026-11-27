import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:swiftmart_frontend/models/models.dart';
import 'package:swiftmart_frontend/providers/product_provider.dart';
import 'package:swiftmart_frontend/services/api_service.dart';
import 'package:swiftmart_frontend/widgets/purchase_dialog.dart';

class _Products extends ProductProvider {
  @override
  Future<void> fetchProducts() async {}
}

void main() {
  testWidgets('phone purchase records extra tax and supplier cost', (tester) async {
    ApiService.configureServer('https://example.test/api');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('{"purchase_id":1}', 201);
    });
    final product = Product(id: '1', name: 'Rice', sku: '001', category: 'Food',
        price: 10, quantity: 0, reorderLevel: 1,
        createdAt: DateTime(2026), updatedAt: DateTime(2026));
    await http.runWithClient(() async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(ChangeNotifierProvider<ProductProvider>(
        create: (_) => _Products(),
        child: MaterialApp(home: Scaffold(body: Builder(builder: (context) =>
          TextButton(onPressed: () => showDialog<void>(
              context: context, builder: (_) => PurchaseDialog(product: product)),
              child: const Text('Open'))))),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Supplier unit price'), '100');
      await tester.tap(find.text('No tax recorded'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tax added to unit price').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Tax rate %'), '10');
      await tester.pump();
      expect(find.textContaining('Total:'), findsOneWidget);
      await tester.tap(find.text('Record purchase'));
      await tester.pumpAndSettle();
      final body = jsonDecode(requests.single.body);
      expect(body['unit_cost_minor'], 10000);
      expect(body['tax_mode'], 'additional');
      expect(body['tax_basis_points'], 1000);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }, () => client);
  });
}
