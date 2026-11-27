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
          version: 5, onCreate: createSchema, onUpgrade: upgradeSchema);
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
  }
}
