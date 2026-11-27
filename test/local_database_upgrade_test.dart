import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:swiftmart_frontend/services/local_database.dart';
import 'package:swiftmart_frontend/services/local_sales.dart';
import 'package:swiftmart_frontend/services/local_stock.dart';
import 'package:swiftmart_frontend/services/local_users.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  for (final oldVersion in [1, 2, 3, 4, 5]) {
    test('upgrade from version $oldVersion preserves local data', () async {
      final directory =
          await Directory.systemTemp.createTemp('swiftmart-upgrade-');
      final path = '${directory.path}/test.db';
      try {
        var db = await databaseFactoryFfi.openDatabase(path,
            options: OpenDatabaseOptions(
              version: oldVersion,
              onCreate: (db, version) async {
                await LocalUsers.createSchema(db);
                if (version >= 2) await LocalStock.createSchema(db);
                if (version >= 2 && version < 5) await db.execute('DROP TABLE local_purchase_entries');
                if (version >= 3) {
                  await LocalSales.createSchema(db);
                  if (version == 3) {
                    await db.execute('DROP TABLE local_direct_draft_items');
                    await db.execute('DROP TABLE local_direct_bill_items');
                  }
                }
              },
            ));
        await db.insert('local_users', {
          'username': 'admin',
          'email': '',
          'role': 'admin',
          'password_salt': 'salt',
          'password_hash': 'hash',
          'created_at': '2025-01-01',
        });
        if (oldVersion >= 2) {
          await db.insert('local_products', {
            'name': 'Rice',
            'sku': '001',
            'category': 'Food',
            'price': 10,
            'quantity': 5,
            'reorder_level': 1,
            'created_at': '2025-01-01',
            'updated_at': '2025-01-01',
          });
        }
        if (oldVersion >= 3) {
          await db.insert('local_drafts', {
            'id': 1, 'owner_id': 1, 'created_at': '2025-01-01',
          });
          await db.insert('local_draft_items', {
            'draft_id': 1, 'product_id': 1, 'product_name': 'Rice',
            'price': 10, 'quantity': 2,
          });
        }
        await db.close();
        db = await databaseFactoryFfi.openDatabase(path,
            options: OpenDatabaseOptions(
                version: 6, onUpgrade: LocalDatabase.upgradeSchema));
        expect((await db.query('local_users')).single['username'], 'admin');
        expect(await db.query('local_products'),
            hasLength(oldVersion >= 2 ? 1 : 0));
        expect(await db.query('local_bills'), isEmpty);
        expect(await db.query('local_direct_draft_items'), isEmpty);
        expect(await db.query('local_direct_bill_items'), isEmpty);
        expect(await db.query('local_purchase_entries'), isEmpty);
        if (oldVersion >= 2) {
          expect((await db.query('local_products')).single['tax_mode'], 'none');
        }
        if (oldVersion >= 3) {
          expect((await db.query('local_drafts')).single['pricing_version'], 0);
          final item = (await db.query('local_draft_items')).single;
          expect(item['quantity'], 2);
          expect(item['tax_mode'], 'none');
        }
        await db.close();
      } finally {
        await directory.delete(recursive: true);
      }
    });
  }
}
