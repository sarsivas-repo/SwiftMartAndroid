import 'package:sqflite/sqflite.dart';

import 'local_users.dart';
import 'local_stock.dart';

class LocalDatabase {
  static Future<LocalUsers>? _opening;

  static Future<LocalUsers> open() {
    return _opening ??= _open();
  }

  static Future<LocalUsers> _open() async {
    try {
      final path = '${await getDatabasesPath()}/swiftmart-test.db';
      final db =
          await openDatabase(path, version: 2, onCreate: (db, version) async {
        await LocalUsers.createSchema(db);
        await LocalStock.createSchema(db);
      }, onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await LocalStock.createSchema(db);
      });
      return LocalUsers(db);
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }
}
