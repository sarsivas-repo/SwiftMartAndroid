import 'package:sqflite/sqflite.dart';

import 'local_users.dart';

class LocalDatabase {
  static Future<LocalUsers>? _opening;

  static Future<LocalUsers> open() {
    return _opening ??= _open();
  }

  static Future<LocalUsers> _open() async {
    try {
      final path = '${await getDatabasesPath()}/swiftmart-test.db';
      final db =
          await openDatabase(path, version: 1, onCreate: (db, version) async {
        await LocalUsers.createSchema(db);
      });
      return LocalUsers(db);
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }
}
