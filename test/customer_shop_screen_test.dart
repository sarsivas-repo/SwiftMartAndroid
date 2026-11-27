import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite/sqflite.dart';
import 'package:swiftmart_frontend/screens/customer_shop_screen.dart';
import 'package:swiftmart_frontend/services/customer_catalog.dart';

class _MemoryStore implements CustomerCatalogStore {
  _MemoryStore(this.catalog);
  CustomerCatalog catalog;
  final List<CustomerCartLine> lines = [];

  @override
  Database get db => throw UnsupportedError('Not used in widget test');

  @override
  Future<CustomerCatalog?> load() async => catalog;

  @override
  Future<void> save(CustomerCatalog value) async => catalog = value;

  @override
  Future<List<CustomerCartLine>> cart() async => List.of(lines);

  @override
  Future<void> setQuantity(CustomerProduct product, int quantity) async {
    lines.removeWhere((line) => line.product.id == product.id);
    if (quantity > 0) {
      lines.add(CustomerCartLine(
          product: product, quantity: quantity, available: true));
    }
  }

  @override
  Future<void> close() async {}
}

void main() {
  late CustomerCatalogStore store;
  late CustomerCatalogClient offline;

  setUp(() async {
    store = _MemoryStore(CustomerCatalog(
      address: 'https://shop.example/api',
      shopName: 'Example Shop',
      syncedAt: DateTime.utc(2026, 1, 1),
      products: const [
        CustomerProduct(
            id: 1, name: 'Rice', category: 'Food', pricePaise: 1235),
      ],
    ));
    offline = CustomerCatalogClient(client: MockClient((request) async {
      throw http.ClientException('offline');
    }));
  });
  tearDown(() async {
    offline.close();
  });

  testWidgets('customer can make and preview an offline order before sharing',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? shared;
    const channel = MethodChannel('com.swiftmart/share');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      expect(call.method, 'shareOrder');
      shared = call.arguments as String;
      return null;
    });
    await tester.pumpWidget(MaterialApp(
      home: CustomerShopScreen(store: store, client: offline),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Example Shop'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
    expect(find.textContaining('INR 12.35'), findsOneWidget);
    expect(find.textContaining('saved catalog is unchanged'), findsOneWidget);
    await tester.tap(find.byTooltip('Add one'));
    await tester.pumpAndSettle();
    expect(find.text('Review order (1 items)'), findsOneWidget);
    await tester.tap(find.text('Review order (1 items)'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Your name'), 'Customer');
    await tester.enterText(
        find.widgetWithText(TextField, 'Delivery address'), 'Example address');
    await tester.ensureVisible(find.text('Preview and share order'));
    await tester.tap(find.text('Preview and share order'));
    await tester.pumpAndSettle();
    expect(find.text('Preview order request'), findsOneWidget);
    expect(shared, isNull);
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(shared, contains('Rice × 1'));
    expect(shared, contains('INR 12.35'));
    expect(shared, contains('Delivery address: Example address'));
    expect(shared, contains('Please confirm availability'));
    expect(shared, contains('tax and delivery extra'));
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await tester.pumpWidget(const SizedBox());
  });
}
