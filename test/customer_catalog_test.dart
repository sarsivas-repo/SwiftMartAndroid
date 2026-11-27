import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:swiftmart_frontend/services/customer_catalog.dart';

const rice =
    CustomerProduct(id: 1, name: 'Rice', category: 'Food', pricePaise: 1235);

CustomerCatalog catalog({
  String address = 'https://shop.example/api',
  List<CustomerProduct> products = const [rice],
}) =>
    CustomerCatalog(
      address: address,
      shopName: 'Example Shop',
      syncedAt: DateTime.utc(2026, 1, 1),
      products: products,
    );

void main() {
  late Database db;
  late CustomerCatalogStore store;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await CustomerCatalogStore.createSchema(db, 1);
    store = CustomerCatalogStore(db);
  });
  tearDown(() => db.close());

  test('fetch validates catalog and never follows redirects', () async {
    final client = CustomerCatalogClient(client: MockClient((request) async {
      expect(
          request.url.toString(), 'https://shop.example/api/customer-catalog');
      expect(request.followRedirects, isFalse);
      return http.Response(
        jsonEncode({
          'shop_name': 'Example Shop',
          'products': [
            {'id': 1, 'name': 'Rice', 'category': 'Food', 'price_paise': 1235}
          ]
        }),
        200,
      );
    }));
    final result = await client.fetch('https://shop.example');
    expect(result.shopName, 'Example Shop');
    expect(result.products.single.pricePaise, 1235);
    client.close();
  });

  test('invalid or duplicate catalog data is rejected', () async {
    final client = CustomerCatalogClient(client: MockClient((request) async {
      return http.Response(
          '{"shop_name":"Shop","products":[{"id":1,"name":"Rice","category":"","price_paise":20},'
          '{"id":1,"name":"Rice","category":"","price_paise":20}]}',
          200);
    }));
    await expectLater(
        client.fetch('https://shop.example'), throwsFormatException);
    client.close();
  });

  test(
      'catalog and cart survive reopening and refresh without losing unavailable items',
      () async {
    await store.save(catalog());
    await store.setQuantity(rice, 2);
    final reopened = CustomerCatalogStore(db);
    expect((await reopened.load())!.products.single.name, 'Rice');
    expect((await reopened.cart()).single.quantity, 2);

    await store.save(catalog(products: const []));
    final missing = (await reopened.cart()).single;
    expect(missing.available, isFalse);
    expect(missing.quantity, 2);
    expect(missing.product.pricePaise, 1235);

    await store.save(catalog(products: const [
      CustomerProduct(id: 1, name: 'Rice', category: 'Food', pricePaise: 1300)
    ]));
    final updated = (await reopened.cart()).single;
    expect(updated.available, isTrue);
    expect(updated.quantity, 2);
    expect(updated.product.pricePaise, 1300);
    await store.save(catalog(address: 'https://other.example/api'));
    expect(await store.cart(), isEmpty);
  });

  test('failed catalog replacement rolls back the prior snapshot and cart',
      () async {
    await store.save(catalog());
    await store.setQuantity(rice, 1);
    await expectLater(store.save(catalog(products: const [rice, rice])),
        throwsA(isA<DatabaseException>()));
    expect((await store.load())!.products.single.id, 1);
    expect((await store.cart()).single.quantity, 1);
  });
}
