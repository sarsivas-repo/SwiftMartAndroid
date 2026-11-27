import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import 'local_stock.dart';
import 'local_users.dart';

class LocalSales {
  final LocalUsers users;
  Database get db => users.db;
  static const _salesRoles = {UserRole.admin, UserRole.cashier};
  static const _customerRoles = {
    UserRole.admin,
    UserRole.manager,
    UserRole.cashier
  };

  LocalSales(this.users);

  static Future<void> createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE local_customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
        email TEXT NOT NULL, phone TEXT NOT NULL, address TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE local_drafts (
        id INTEGER PRIMARY KEY AUTOINCREMENT, owner_id INTEGER NOT NULL,
        customer_id INTEGER, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE local_draft_items (
        draft_id INTEGER NOT NULL, product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL, price REAL NOT NULL, quantity INTEGER NOT NULL,
        PRIMARY KEY(draft_id, product_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE local_bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT, customer_id INTEGER,
        subtotal REAL NOT NULL, tax_amount REAL NOT NULL, total REAL NOT NULL,
        payment_method TEXT NOT NULL, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE local_bill_items (
        bill_id INTEGER NOT NULL, product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL, price REAL NOT NULL, quantity INTEGER NOT NULL,
        PRIMARY KEY(bill_id, product_id)
      )
    ''');
    await createDirectSchema(db);
  }

  static Future<void> createDirectSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_direct_draft_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT, draft_id INTEGER NOT NULL,
        product_name TEXT NOT NULL, price_paise INTEGER NOT NULL, quantity INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_direct_bill_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT, bill_id INTEGER NOT NULL,
        product_name TEXT NOT NULL, price_paise INTEGER NOT NULL, quantity INTEGER NOT NULL
      )
    ''');
  }

  static int _id(String value) {
    final id = int.tryParse(value);
    if (id == null || id <= 0) throw ArgumentError('Invalid identifier.');
    return id;
  }

  Future<Customer> _customer(DatabaseExecutor tx, int id) async {
    final rows =
        await tx.query('local_customers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw StateError('Customer not found.');
    final summary = (await tx.rawQuery(
            'SELECT COUNT(*) AS bill_count, COALESCE(SUM(total), 0) AS total_spent FROM local_bills WHERE customer_id = ?',
            [id]))
        .single;
    return Customer.fromJson({...rows.single, ...summary, 'id': id.toString()});
  }

  Future<List<Customer>> customers() async {
    await users.requireRoles(db, _customerRoles);
    final rows =
        await db.query('local_customers', orderBy: 'name COLLATE NOCASE');
    return Future.wait(rows.map((row) => _customer(db, row['id'] as int)));
  }

  Future<Customer> registerCustomer(
      String name, String email, String phone, String address) async {
    if (name.trim().isEmpty) throw ArgumentError('Customer name is required.');
    return db.transaction((tx) async {
      await users.requireRoles(tx, _customerRoles);
      if (email.trim().isNotEmpty &&
          (await tx.query('local_customers',
                  where: 'email = ? COLLATE NOCASE', whereArgs: [email.trim()]))
              .isNotEmpty) {
        throw StateError('Email already registered.');
      }
      final id = await tx.insert('local_customers', {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'address': address.trim(),
        'created_at': LocalStock.now(),
      });
      return _customer(tx, id);
    });
  }

  Future<Customer> updateCustomer(
      String customerId, String name, String email, String phone) async {
    if (name.trim().isEmpty) throw ArgumentError('Customer name is required.');
    final id = _id(customerId);
    return db.transaction((tx) async {
      await users.requireRoles(tx, _customerRoles);
      if (email.trim().isNotEmpty &&
          (await tx.query('local_customers',
                  where: 'email = ? COLLATE NOCASE AND id != ?',
                  whereArgs: [email.trim(), id]))
              .isNotEmpty) {
        throw StateError('Email already registered.');
      }
      final changed = await tx.update(
          'local_customers',
          {
            'name': name.trim(),
            'email': email.trim(),
            'phone': phone.trim(),
          },
          where: 'id = ?',
          whereArgs: [id]);
      if (changed != 1) throw StateError('Customer not found.');
      return _customer(tx, id);
    });
  }

  Future<Bill> _draft(DatabaseExecutor tx, String id, User actor) async {
    final draftId = _id(id);
    final rows = await tx.query('local_drafts',
        where: 'id = ? AND owner_id = ?', whereArgs: [draftId, _id(actor.id)]);
    if (rows.isEmpty) throw StateError('Draft not found.');
    final row = rows.single;
    final items = await tx.query('local_draft_items',
        where: 'draft_id = ?', whereArgs: [draftId], orderBy: 'rowid');
    final billItems = items
        .map((item) => BillItem(
              id: item['product_id'].toString(),
              billId: id,
              productId: item['product_id'].toString(),
              productName: item['product_name'] as String,
              price: (item['price'] as num).toDouble(),
              quantity: item['quantity'] as int,
              subtotal:
                  (item['price'] as num).toDouble() * (item['quantity'] as int),
            ))
        .toList();
    final directItems = await tx.query('local_direct_draft_items',
        where: 'draft_id = ?', whereArgs: [draftId], orderBy: 'id');
    billItems.addAll(directItems.map((item) {
      final itemId = 'direct:${item['id']}';
      final price = (item['price_paise'] as int) / 100;
      final quantity = item['quantity'] as int;
      return BillItem(id: itemId, billId: id, productId: itemId,
          productName: item['product_name'] as String, price: price,
          quantity: quantity, subtotal: price * quantity);
    }));
    final subtotal =
        billItems.fold<double>(0, (sum, item) => sum + item.subtotal);
    return Bill(
        id: id,
        customerId: row['customer_id']?.toString() ?? 'guest',
        subtotal: subtotal,
        taxAmount: 0,
        total: subtotal,
        status: BillStatus.pending,
        paymentMethod: 'cash',
        createdAt: DateTime.parse(row['created_at'] as String),
        items: billItems);
  }

  Future<List<Bill>> drafts() async {
    final actor = await users.requireRoles(db, _salesRoles);
    final rows = await db.query('local_drafts',
        where: 'owner_id = ?', whereArgs: [_id(actor.id)], orderBy: 'id DESC');
    return Future.wait(
        rows.map((row) => _draft(db, row['id'].toString(), actor)));
  }

  Future<Bill> createDraft(int? customerId) async => db.transaction((tx) async {
        final actor = await users.requireRoles(tx, _salesRoles);
        if (customerId != null) await _customer(tx, customerId);
        final id = await tx.insert('local_drafts', {
          'owner_id': _id(actor.id),
          'customer_id': customerId,
          'created_at': LocalStock.now(),
        });
        return _draft(tx, id.toString(), actor);
      });

  Future<Bill> setCustomer(String draftId, int? customerId) async =>
      db.transaction((tx) async {
        final actor = await users.requireRoles(tx, _salesRoles);
        await _draft(tx, draftId, actor);
        if (customerId != null) await _customer(tx, customerId);
        await tx.update('local_drafts', {'customer_id': customerId},
            where: 'id = ?', whereArgs: [_id(draftId)]);
        return _draft(tx, draftId, actor);
      });

  Future<Bill> setItem(String draftId, String productId, int quantity,
      {bool add = false}) async {
    if (quantity <= 0) {
      throw ArgumentError('Quantity must be greater than zero.');
    }
    return db.transaction((tx) async {
      final actor = await users.requireRoles(tx, _salesRoles);
      await _draft(tx, draftId, actor);
      final products = await tx.query('local_products',
          where: 'id = ?', whereArgs: [_id(productId)]);
      if (products.isEmpty) throw StateError('Product not found.');
      final product = LocalStock.product(products.single);
      final existing = await tx.query('local_draft_items',
          where: 'draft_id = ? AND product_id = ?',
          whereArgs: [_id(draftId), _id(productId)]);
      if (!add && existing.isEmpty) throw StateError('Draft item not found.');
      final next = quantity +
          (add && existing.isNotEmpty ? existing.single['quantity'] as int : 0);
      if (next > product.quantity) throw StateError('Insufficient stock.');
      await tx.insert(
          'local_draft_items',
          {
            'draft_id': _id(draftId),
            'product_id': _id(productId),
            'product_name': product.name,
            'price':
                existing.isEmpty ? product.price : existing.single['price'],
            'quantity': next,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      return _draft(tx, draftId, actor);
    });
  }

  Future<Bill> addDirectItem(String draftId, String name, int quantity, int pricePaise) async {
    if (name.trim().isEmpty || name.runes.length > 255 || quantity <= 0 ||
        quantity > 1000000 || pricePaise < 0 || pricePaise > 9999999999) {
      throw ArgumentError('Invalid direct-sale item.');
    }
    return db.transaction((tx) async {
      final actor = await users.requireRoles(tx, _salesRoles);
      await _draft(tx, draftId, actor);
      await tx.insert('local_direct_draft_items', {
        'draft_id': _id(draftId), 'product_name': name.trim(),
        'quantity': quantity, 'price_paise': pricePaise,
      });
      return _draft(tx, draftId, actor);
    });
  }

  Future<Bill> changeDirectItem(String draftId, String itemId, {int? quantity}) async {
    if (quantity != null && (quantity <= 0 || quantity > 1000000)) {
      throw ArgumentError('Invalid quantity.');
    }
    final directId = _id(itemId.substring(7));
    return db.transaction((tx) async {
      final actor = await users.requireRoles(tx, _salesRoles);
      await _draft(tx, draftId, actor);
      final count = quantity == null
          ? await tx.delete('local_direct_draft_items',
              where: 'id = ? AND draft_id = ?', whereArgs: [directId, _id(draftId)])
          : await tx.update('local_direct_draft_items', {'quantity': quantity},
              where: 'id = ? AND draft_id = ?', whereArgs: [directId, _id(draftId)]);
      if (count != 1) throw StateError('Direct-sale item not found.');
      return _draft(tx, draftId, actor);
    });
  }

  Future<Bill> removeItem(String draftId, String productId) async =>
      db.transaction((tx) async {
        final actor = await users.requireRoles(tx, _salesRoles);
        await _draft(tx, draftId, actor);
        final deleted = await tx.delete('local_draft_items',
            where: 'draft_id = ? AND product_id = ?',
            whereArgs: [_id(draftId), _id(productId)]);
        if (deleted != 1) throw StateError('Draft item not found.');
        return _draft(tx, draftId, actor);
      });

  Future<void> deleteDraft(String draftId) async => db.transaction((tx) async {
        final actor = await users.requireRoles(tx, _salesRoles);
        await _draft(tx, draftId, actor);
        await tx.delete('local_draft_items',
            where: 'draft_id = ?', whereArgs: [_id(draftId)]);
        await tx.delete('local_direct_draft_items',
            where: 'draft_id = ?', whereArgs: [_id(draftId)]);
        await tx
            .delete('local_drafts', where: 'id = ?', whereArgs: [_id(draftId)]);
      });

  Future<Map<String, dynamic>> checkout(
      String draftId, double tax, String paymentMethod) async {
    if (!tax.isFinite || tax < 0 || paymentMethod.trim().isEmpty) {
      throw ArgumentError('Invalid tax or payment method.');
    }
    return db.transaction((tx) async {
      final actor = await users.requireRoles(tx, _salesRoles);
      final draft = await _draft(tx, draftId, actor);
      if (draft.items.isEmpty) {
        throw StateError('Cannot checkout an empty bill.');
      }
      for (final item in draft.items) {
        if (item.productId.startsWith('direct:')) continue;
        final rows = await tx.query('local_products',
            where: 'id = ?', whereArgs: [_id(item.productId)]);
        if (rows.isEmpty || (rows.single['quantity'] as int) < item.quantity) {
          throw StateError('Insufficient stock for ${item.productName}.');
        }
      }
      final total = draft.subtotal + tax;
      final id = await tx.insert('local_bills', {
        'customer_id':
            draft.customerId == 'guest' ? null : _id(draft.customerId),
        'subtotal': draft.subtotal,
        'tax_amount': tax,
        'total': total,
        'payment_method': paymentMethod,
        'created_at': LocalStock.now(),
      });
      for (final item in draft.items) {
        if (item.productId.startsWith('direct:')) {
          final direct = await tx.query('local_direct_draft_items',
              where: 'id = ? AND draft_id = ?',
              whereArgs: [_id(item.productId.substring(7)), _id(draftId)]);
          if (direct.length != 1) throw StateError('Direct-sale item not found.');
          await tx.insert('local_direct_bill_items', {
            'bill_id': id, 'product_name': item.productName,
            'price_paise': direct.single['price_paise'], 'quantity': item.quantity,
          });
          continue;
        }
        final rows = await tx.query('local_products',
            where: 'id = ?', whereArgs: [_id(item.productId)]);
        final product = LocalStock.product(rows.single);
        await tx.update(
            'local_products',
            {
              'quantity': product.quantity - item.quantity,
              'updated_at': LocalStock.now(),
            },
            where: 'id = ?',
            whereArgs: [_id(item.productId)]);
        await LocalStock.log(
            tx, product, actor, 'sale', -item.quantity, 'Sale #$id');
        await tx.insert('local_bill_items', {
          'bill_id': id,
          'product_id': _id(item.productId),
          'product_name': item.productName,
          'price': item.price,
          'quantity': item.quantity,
        });
      }
      await tx.delete('local_draft_items',
          where: 'draft_id = ?', whereArgs: [_id(draftId)]);
      await tx.delete('local_direct_draft_items',
          where: 'draft_id = ?', whereArgs: [_id(draftId)]);
      await tx
          .delete('local_drafts', where: 'id = ?', whereArgs: [_id(draftId)]);
      return {
        'bill_id': id,
        'subtotal': draft.subtotal,
        'tax': tax,
        'total': total
      };
    });
  }

  Future<Bill> _bill(DatabaseExecutor tx, Map<String, Object?> row) async {
    final id = row['id'].toString();
    final items = await tx.query('local_bill_items',
        where: 'bill_id = ?', whereArgs: [_id(id)], orderBy: 'rowid');
    final billItems = items
        .map((item) => BillItem(
              id: item['product_id'].toString(),
              billId: id,
              productId: item['product_id'].toString(),
              productName: item['product_name'] as String,
              price: (item['price'] as num).toDouble(),
              quantity: item['quantity'] as int,
              subtotal:
                  (item['price'] as num).toDouble() * (item['quantity'] as int),
            ))
        .toList();
    final directItems = await tx.query('local_direct_bill_items',
        where: 'bill_id = ?', whereArgs: [_id(id)], orderBy: 'id');
    billItems.addAll(directItems.map((item) {
      final itemId = 'direct:${item['id']}';
      final price = (item['price_paise'] as int) / 100;
      final quantity = item['quantity'] as int;
      return BillItem(id: itemId, billId: id, productId: itemId,
          productName: item['product_name'] as String, price: price,
          quantity: quantity, subtotal: price * quantity);
    }));
    return Bill(
      id: id,
      customerId: row['customer_id']?.toString() ?? 'guest',
      subtotal: (row['subtotal'] as num).toDouble(),
      taxAmount: (row['tax_amount'] as num).toDouble(),
      total: (row['total'] as num).toDouble(),
      status: BillStatus.completed,
      paymentMethod: row['payment_method'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      items: billItems,
    );
  }

  Future<List<Bill>> customerHistory(String customerId) async {
    await users.requireRoles(db, _customerRoles);
    final id = _id(customerId);
    await _customer(db, id);
    final rows = await db.query('local_bills',
        where: 'customer_id = ?', whereArgs: [id], orderBy: 'id DESC');
    return Future.wait(rows.map((row) => _bill(db, row)));
  }
}
