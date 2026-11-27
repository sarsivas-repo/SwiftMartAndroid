import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import 'server_settings.dart';

class CustomerProduct {
  const CustomerProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.pricePaise,
  });

  final int id;
  final String name;
  final String category;
  final int pricePaise;

  factory CustomerProduct.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final category = json['category'];
    final price = json['price_paise'];
    if (id is! int ||
        id <= 0 ||
        name is! String ||
        name.trim().isEmpty ||
        category is! String ||
        price is! int ||
        price < 0) {
      throw const FormatException('Invalid catalog product');
    }
    return CustomerProduct(
        id: id, name: name, category: category, pricePaise: price);
  }
}

class CustomerCatalog {
  const CustomerCatalog({
    required this.address,
    required this.shopName,
    required this.syncedAt,
    required this.products,
  });

  final String address;
  final String shopName;
  final DateTime syncedAt;
  final List<CustomerProduct> products;
}

class CustomerCartLine {
  const CustomerCartLine({
    required this.product,
    required this.quantity,
    required this.available,
  });

  final CustomerProduct product;
  final int quantity;
  final bool available;
}

class CustomerCatalogClient {
  CustomerCatalogClient({http.Client? client})
      : _client = client ?? http.Client();
  final http.Client _client;

  Future<CustomerCatalog> fetch(String address) async {
    final normalized = ServerSettings.normalizeAddress(address);
    final request =
        http.Request('GET', Uri.parse('$normalized/customer-catalog'))
          ..followRedirects = false;
    final response =
        await _client.send(request).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError(
          'Shop catalog unavailable (HTTP ${response.statusCode}).');
    }
    final body = await response.stream
        .bytesToString()
        .timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(body);
    if (decoded is! Map ||
        decoded['shop_name'] is! String ||
        (decoded['shop_name'] as String).trim().isEmpty ||
        decoded['products'] is! List) {
      throw const FormatException('Invalid shop catalog');
    }
    final products = <CustomerProduct>[];
    final ids = <int>{};
    for (final item in decoded['products'] as List) {
      if (item is! Map) throw const FormatException('Invalid catalog product');
      final product = CustomerProduct.fromJson(Map<String, dynamic>.from(item));
      if (!ids.add(product.id)) {
        throw const FormatException('Duplicate product in catalog');
      }
      products.add(product);
    }
    return CustomerCatalog(
      address: normalized,
      shopName: (decoded['shop_name'] as String).trim(),
      syncedAt: DateTime.now().toUtc(),
      products: products,
    );
  }

  void close() => _client.close();
}

class CustomerCatalogStore {
  CustomerCatalogStore(this.db);
  final Database db;

  static Future<CustomerCatalogStore> open() async {
    final path = '${await getDatabasesPath()}/swiftmart-customer.db';
    final db = await openDatabase(path, version: 1, onCreate: createSchema);
    return CustomerCatalogStore(db);
  }

  static Future<void> createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE catalog_meta (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        address TEXT NOT NULL, shop_name TEXT NOT NULL, synced_at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE catalog_products (
        id INTEGER PRIMARY KEY, name TEXT NOT NULL, category TEXT NOT NULL,
        price_paise INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE catalog_cart (
        product_id INTEGER PRIMARY KEY, name TEXT NOT NULL,
        category TEXT NOT NULL, price_paise INTEGER NOT NULL,
        quantity INTEGER NOT NULL CHECK (quantity BETWEEN 1 AND 99)
      )''');
  }

  Future<CustomerCatalog?> load() async {
    final meta =
        await db.query('catalog_meta', where: 'id = ?', whereArgs: [1]);
    if (meta.isEmpty) return null;
    final products = await db.query('catalog_products', orderBy: 'name, id');
    return CustomerCatalog(
      address: meta.single['address'] as String,
      shopName: meta.single['shop_name'] as String,
      syncedAt: DateTime.parse(meta.single['synced_at'] as String),
      products: products.map(CustomerProduct.fromJson).toList(),
    );
  }

  Future<void> save(CustomerCatalog catalog) async {
    await db.transaction((tx) async {
      final old =
          await tx.query('catalog_meta', where: 'id = ?', whereArgs: [1]);
      if (old.isNotEmpty && old.single['address'] != catalog.address) {
        await tx.delete('catalog_cart');
      }
      await tx.delete('catalog_products');
      final batch = tx.batch();
      for (final product in catalog.products) {
        batch.insert('catalog_products', {
          'id': product.id,
          'name': product.name,
          'category': product.category,
          'price_paise': product.pricePaise,
        });
      }
      await batch.commit(noResult: true);
      await tx.rawUpdate('''
        UPDATE catalog_cart SET
          name = (SELECT name FROM catalog_products WHERE id = product_id),
          category = (SELECT category FROM catalog_products WHERE id = product_id),
          price_paise = (SELECT price_paise FROM catalog_products WHERE id = product_id)
        WHERE product_id IN (SELECT id FROM catalog_products)
      ''');
      await tx.insert(
          'catalog_meta',
          {
            'id': 1,
            'address': catalog.address,
            'shop_name': catalog.shopName,
            'synced_at': catalog.syncedAt.toUtc().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<CustomerCartLine>> cart() async {
    final rows = await db.rawQuery('''
      SELECT c.product_id AS id, c.name, c.category, c.price_paise, c.quantity,
             CASE WHEN p.id IS NULL THEN 0 ELSE 1 END AS available
      FROM catalog_cart c LEFT JOIN catalog_products p ON p.id = c.product_id
      ORDER BY c.name, c.product_id
    ''');
    return rows
        .map((row) => CustomerCartLine(
              product: CustomerProduct.fromJson(row),
              quantity: row['quantity'] as int,
              available: row['available'] == 1,
            ))
        .toList();
  }

  Future<void> setQuantity(CustomerProduct product, int quantity) async {
    if (quantity < 0 || quantity > 99) {
      throw RangeError.range(quantity, 0, 99, 'quantity');
    }
    if (quantity == 0) {
      await db.delete('catalog_cart',
          where: 'product_id = ?', whereArgs: [product.id]);
      return;
    }
    await db.insert(
        'catalog_cart',
        {
          'product_id': product.id,
          'name': product.name,
          'category': product.category,
          'price_paise': product.pricePaise,
          'quantity': quantity,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() => db.close();
}
