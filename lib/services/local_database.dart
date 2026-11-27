import 'package:sqflite/sqflite.dart';

import 'local_users.dart';
import 'local_stock.dart';
import 'local_sales.dart';

class LocalDatabase {
  static Future<LocalUsers>? _opening;

  static Future<LocalUsers> open() {
    return _opening ??= _open();
  }

  static Future<LocalUsers> _open() async {
    try {
      final path = '${await getDatabasesPath()}/swiftmart-test.db';
      final db = await openDatabase(path,
          version: 6, onCreate: createSchema, onUpgrade: upgradeSchema);
      return LocalUsers(db);
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  static Future<void> createSchema(Database db, int version) async {
    await LocalUsers.createSchema(db);
    await LocalStock.createSchema(db);
    await LocalSales.createSchema(db);
    await createTaxSchema(db);
  }

  static Future<void> createTaxSchema(DatabaseExecutor db) async {
    await db.execute("ALTER TABLE local_products ADD COLUMN tax_mode TEXT NOT NULL DEFAULT 'none'");
    await db.execute("ALTER TABLE local_products ADD COLUMN tax_basis_points INTEGER NOT NULL DEFAULT 0");
    await db.execute("ALTER TABLE local_products ADD COLUMN mrp_minor INTEGER");
    await db.execute("ALTER TABLE local_drafts ADD COLUMN pricing_version INTEGER NOT NULL DEFAULT 0");
    for (final table in ['local_draft_items', 'local_direct_draft_items',
      'local_bill_items', 'local_direct_bill_items']) {
      await db.execute("ALTER TABLE $table ADD COLUMN tax_mode TEXT NOT NULL DEFAULT 'none'");
      await db.execute("ALTER TABLE $table ADD COLUMN tax_basis_points INTEGER NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE $table ADD COLUMN tax_minor INTEGER NOT NULL DEFAULT 0");
    }
    await db.execute("ALTER TABLE local_draft_items ADD COLUMN mrp_minor INTEGER");
  }

  static Future<void> upgradeSchema(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await LocalStock.createSchema(db);
    if (oldVersion < 3) await LocalSales.createSchema(db);
    if (oldVersion < 4 && newVersion >= 4) {
      await LocalSales.createDirectSchema(db);
    }
    if (oldVersion < 5 && newVersion >= 5) {
      await LocalStock.createPurchaseSchema(db);
    }
    if (oldVersion < 6 && newVersion >= 6) {
      await createTaxSchema(db);
    }
  }
}
