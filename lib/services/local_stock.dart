import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import 'local_users.dart';

class LocalStock {
  final LocalUsers users;
  Database get db => users.db;
  static const _all = {UserRole.admin, UserRole.manager, UserRole.cashier};
  static const _managers = {UserRole.admin, UserRole.manager};

  LocalStock(this.users);

  static Future<void> createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE local_products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sku TEXT NOT NULL COLLATE NOCASE UNIQUE,
        category TEXT NOT NULL,
        price REAL NOT NULL CHECK(price >= 0),
        quantity INTEGER NOT NULL DEFAULT 0 CHECK(quantity >= 0),
        reorder_level INTEGER NOT NULL CHECK(reorder_level >= 0),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE local_stock_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES local_products(id),
        product_name TEXT NOT NULL,
        username TEXT NOT NULL,
        role TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        notes TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await createPurchaseSchema(db);
  }

  static Future<void> createPurchaseSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_purchase_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL UNIQUE,
        product_id INTEGER NOT NULL, user_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL, unit_cost_minor INTEGER NOT NULL,
        tax_mode TEXT NOT NULL, tax_basis_points INTEGER NOT NULL,
        subtotal_minor INTEGER NOT NULL, tax_minor INTEGER NOT NULL, total_minor INTEGER NOT NULL,
        supplier TEXT NOT NULL, invoice_reference TEXT NOT NULL, created_at TEXT NOT NULL
      )
    ''');
  }

  static String now() => DateTime.now().toIso8601String();

  static Product product(Map<String, Object?> row) => Product.fromJson({
        ...row,
        'id': row['id'].toString(),
      });

  Future<List<Product>> products({bool lowStock = false}) async {
    await users.requireRoles(db, _all);
    final rows = await db.query('local_products',
        where: lowStock ? 'quantity <= reorder_level' : null,
        orderBy: 'name COLLATE NOCASE');
    return rows.map(product).toList();
  }

  Future<Product> add(String name, String sku, String category, double price,
      int reorderLevel) async {
    if (name.trim().isEmpty || sku.trim().isEmpty) {
      throw ArgumentError('Product name and barcode are required.');
    }
    if (!price.isFinite || price < 0 || reorderLevel < 0) {
      throw ArgumentError('Price and reorder level must be non-negative.');
    }
    return db.transaction((tx) async {
      await users.requireRoles(tx, _managers);
      final timestamp = now();
      final id = await tx.insert('local_products', {
        'name': name.trim(),
        'sku': sku.trim(),
        'category': category.trim(),
        'price': price,
        'reorder_level': reorderLevel,
        'created_at': timestamp,
        'updated_at': timestamp,
      });
      return _product(tx, id.toString());
    });
  }

  Future<Product> adjust(String productId, int quantity,
      {bool restock = false, String notes = ''}) async {
    if (quantity == 0 || (restock && quantity < 0)) {
      throw ArgumentError('Invalid stock quantity.');
    }
    return db.transaction((tx) async {
      final actor = await users.requireRoles(tx, restock ? _all : _managers);
      final existing = await _product(tx, productId);
      if (existing.quantity + quantity < 0) {
        throw StateError('Insufficient stock.');
      }
      await tx.update(
          'local_products',
          {
            'quantity': existing.quantity + quantity,
            'updated_at': now(),
          },
          where: 'id = ?',
          whereArgs: [productId]);
      await log(
          tx,
          existing,
          actor,
          restock ? 'add' : 'adjustment',
          quantity,
          notes.trim().isEmpty
              ? (restock ? 'Manual restock' : 'Manual stock update')
              : notes.trim());
      return _product(tx, productId);
    });
  }

  Future<Map<String, dynamic>> purchase(
      String productId, String requestId, int quantity, int unitCostMinor,
      String taxMode, int taxBasisPoints, String supplier, String invoiceReference) async {
    const maxMinor = 9999999999;
    if (!RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(requestId) ||
        quantity <= 0 || quantity > 1000000 || unitCostMinor < 0 ||
        unitCostMinor > maxMinor ~/ quantity || taxBasisPoints < 0 || taxBasisPoints > 10000 ||
        !{'none', 'inclusive', 'additional'}.contains(taxMode) ||
        (taxMode == 'none' && taxBasisPoints != 0) ||
        supplier.trim().runes.length > 255 || invoiceReference.trim().runes.length > 255) {
      throw ArgumentError('Invalid purchase.');
    }
    final amount = unitCostMinor * quantity;
    final base = taxMode == 'inclusive'
        ? (amount * 10000 + (10000 + taxBasisPoints) ~/ 2) ~/ (10000 + taxBasisPoints)
        : amount;
    final tax = taxMode == 'inclusive' ? amount - base :
        taxMode == 'additional' ? (amount * taxBasisPoints + 5000) ~/ 10000 : 0;
    final total = base + tax;
    if (total > maxMinor) throw ArgumentError('Purchase total is too large.');
    return db.transaction((tx) async {
      final actor = await users.requireRoles(tx, _all);
      final product = await _product(tx, productId);
      final request = requestId.toLowerCase();
      final existing = await tx.query('local_purchase_entries',
          where: 'request_id = ?', whereArgs: [request]);
      if (existing.isNotEmpty) {
        final row = existing.single;
        if (row['product_id'] != int.parse(productId) || row['user_id'] != int.parse(actor.id) ||
            row['quantity'] != quantity || row['unit_cost_minor'] != unitCostMinor ||
            row['tax_mode'] != taxMode || row['tax_basis_points'] != taxBasisPoints ||
            row['supplier'] != supplier.trim() || row['invoice_reference'] != invoiceReference.trim()) {
          throw StateError('Purchase request ID was already used.');
        }
        return {'purchase_id': row['id'], 'subtotal_minor': base, 'tax_minor': tax, 'total_minor': total};
      }
      final id = await tx.insert('local_purchase_entries', {
        'request_id': request, 'product_id': int.parse(productId), 'user_id': int.parse(actor.id),
        'quantity': quantity, 'unit_cost_minor': unitCostMinor, 'tax_mode': taxMode,
        'tax_basis_points': taxBasisPoints, 'subtotal_minor': base, 'tax_minor': tax,
        'total_minor': total, 'supplier': supplier.trim(), 'invoice_reference': invoiceReference.trim(),
        'created_at': now(),
      });
      await tx.update('local_products', {'quantity': product.quantity + quantity, 'updated_at': now()},
          where: 'id = ?', whereArgs: [productId]);
      await log(tx, product, actor, 'add', quantity, 'Purchase #$id');
      return {'purchase_id': id, 'subtotal_minor': base, 'tax_minor': tax, 'total_minor': total};
    });
  }

  Future<void> reorder(String productId, int level) async {
    if (level < 0) throw ArgumentError('Reorder level must be non-negative.');
    await db.transaction((tx) async {
      await users.requireRoles(tx, _managers);
      final changed = await tx.update(
          'local_products', {'reorder_level': level, 'updated_at': now()},
          where: 'id = ?', whereArgs: [productId]);
      if (changed != 1) throw StateError('Product not found.');
    });
  }

  Future<List<StockLog>> logs({String? productId}) async {
    await users.requireRoles(db, _all);
    final rows = await db.query('local_stock_logs',
        where: productId == null ? null : 'product_id = ?',
        whereArgs: productId == null ? null : [productId],
        orderBy: 'id DESC');
    return rows
        .map((row) => StockLog.fromJson({
              ...row,
              'id': row['id'].toString(),
              'product_id': row['product_id'].toString(),
            }))
        .toList();
  }

  Future<Product> _product(DatabaseExecutor tx, String id) async {
    final rows =
        await tx.query('local_products', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw StateError('Product not found.');
    return product(rows.single);
  }

  static Future<void> log(DatabaseExecutor tx, Product product, User actor,
      String type, int quantity, String notes) async {
    await tx.insert('local_stock_logs', {
      'product_id': int.parse(product.id),
      'product_name': product.name,
      'username': actor.username,
      'role': actor.role.name.toUpperCase(),
      'type': type,
      'quantity': quantity,
      'notes': notes,
      'created_at': now(),
    });
  }
}
