import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

/// Persistent, device-local test accounts. This is not a server identity store.
class LocalUsers {
  final Database db;
  final _kdf =
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 210000, bits: 256);
  int? _sessionUserId;

  LocalUsers(this.db);

  static Future<void> createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE local_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL COLLATE NOCASE UNIQUE,
        email TEXT NOT NULL,
        mobile TEXT NOT NULL DEFAULT '',
        role TEXT NOT NULL CHECK (role IN ('admin', 'manager', 'cashier')),
        is_active INTEGER NOT NULL DEFAULT 1,
        must_change_password INTEGER NOT NULL DEFAULT 0,
        password_salt TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<bool> get needsSetup async {
    final result =
        await db.rawQuery('SELECT COUNT(*) AS count FROM local_users');
    return Sqflite.firstIntValue(result) == 0;
  }

  Future<void> setupAdmin(String username, String password) async {
    final values =
        await _newUser(username, '', password, UserRole.admin, false);
    await db.transaction((tx) async {
      final result =
          await tx.rawQuery('SELECT COUNT(*) AS count FROM local_users');
      if (Sqflite.firstIntValue(result) != 0) {
        throw StateError('Standalone setup has already been completed.');
      }
      await tx.insert('local_users', values);
    });
  }

  Future<User> login(String username, String password) async {
    _sessionUserId = null;
    final rows = await db.query('local_users',
        where: 'username = ? COLLATE NOCASE',
        whereArgs: [username.trim()],
        limit: 1);
    if (rows.isEmpty ||
        rows.single['is_active'] != 1 ||
        !await _verifyPassword(password, rows.single)) {
      throw StateError('Invalid username or password, or account is inactive.');
    }
    _sessionUserId = rows.single['id'] as int;
    return _user(rows.single);
  }

  void logout() => _sessionUserId = null;

  Future<Map<String, Object?>> _session(DatabaseExecutor executor,
      {bool admin = false}) async {
    final id = _sessionUserId;
    if (id == null) throw StateError('Please sign in.');
    final rows = await executor.query('local_users',
        where: 'id = ? AND is_active = 1', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw StateError('Session is no longer active.');
    if (admin && rows.single['role'] != 'admin') {
      throw StateError('Administrator permission required.');
    }
    return rows.single;
  }

  Future<List<User>> listUsers() async {
    await _session(db, admin: true);
    return (await db.query('local_users', orderBy: 'id DESC'))
        .map(_user)
        .toList();
  }

  Future<User> currentUser() async => _user(await _session(db));

  Future<User> updateProfile(
      {required String email, required String mobile}) async {
    return db.transaction((tx) async {
      final current = await _session(tx);
      await tx.update(
          'local_users', {'email': email.trim(), 'mobile': mobile.trim()},
          where: 'id = ?', whereArgs: [current['id']]);
      return _user((await tx.query('local_users',
              where: 'id = ?', whereArgs: [current['id']]))
          .single);
    });
  }

  Future<User> createUser(
      String username, String email, String password, UserRole role) async {
    await _session(db, admin: true);
    final values = await _newUser(username, email, password, role, true);
    return db.transaction((tx) async {
      await _session(tx, admin: true);
      final id = await tx.insert('local_users', values);
      return _user(
          (await tx.query('local_users', where: 'id = ?', whereArgs: [id]))
              .single);
    });
  }

  Future<User> updateUser(String id,
      {required String username,
      required String email,
      required String mobile,
      required UserRole role,
      required bool active}) async {
    if (username.trim().isEmpty) throw ArgumentError('Username is required.');
    final userId = int.tryParse(id);
    if (userId == null) throw ArgumentError('Invalid user ID.');
    return db.transaction((tx) async {
      final current = await _session(tx, admin: true);
      final rows =
          await tx.query('local_users', where: 'id = ?', whereArgs: [userId]);
      if (rows.isEmpty) throw StateError('User not found.');
      if (current['id'] == userId && (!active || role != UserRole.admin)) {
        throw StateError(
            'You cannot deactivate or remove your own administrator role.');
      }
      await tx.update(
          'local_users',
          {
            'username': username.trim(),
            'email': email.trim(),
            'mobile': mobile.trim(),
            'role': role.name,
            'is_active': active ? 1 : 0,
          },
          where: 'id = ?',
          whereArgs: [userId]);
      return _user(
          (await tx.query('local_users', where: 'id = ?', whereArgs: [userId]))
              .single);
    });
  }

  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    final user = await _session(db);
    if (!await _verifyPassword(currentPassword, user)) {
      throw StateError('Current password is incorrect.');
    }
    final password = await _passwordValues(newPassword);
    await db.transaction((tx) async {
      final current = await _session(tx);
      if (current['password_hash'] != user['password_hash']) {
        throw StateError('Password changed; sign in again.');
      }
      await tx.update('local_users', {...password, 'must_change_password': 0},
          where: 'id = ?', whereArgs: [current['id']]);
    });
  }

  Future<void> resetPassword(String id, String newPassword) async {
    await _session(db, admin: true);
    final password = await _passwordValues(newPassword);
    await db.transaction((tx) async {
      await _session(tx, admin: true);
      final changed = await tx.update(
          'local_users', {...password, 'must_change_password': 1},
          where: 'id = ?', whereArgs: [int.tryParse(id)]);
      if (changed != 1) throw StateError('User not found.');
    });
  }

  Future<void> deleteUser(String id) async {
    await db.transaction((tx) async {
      final current = await _session(tx, admin: true);
      final userId = int.tryParse(id);
      if (userId == null) throw ArgumentError('Invalid user ID.');
      if (current['id'] == userId)
        throw StateError('You cannot delete your own account.');
      if (await tx
              .delete('local_users', where: 'id = ?', whereArgs: [userId]) !=
          1) {
        throw StateError('User not found.');
      }
    });
  }

  Future<Map<String, Object?>> _newUser(String username, String email,
      String password, UserRole role, bool mustChange) async {
    if (username.trim().isEmpty) throw ArgumentError('Username is required.');
    return {
      'username': username.trim(),
      'email': email.trim(),
      'role': role.name,
      'must_change_password': mustChange ? 1 : 0,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      ...await _passwordValues(password),
    };
  }

  Future<Map<String, String>> _passwordValues(String password) async {
    if (password.length < 8)
      throw ArgumentError('Password must be at least 8 characters.');
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final key = await _kdf.deriveKey(
        secretKey: SecretKey(utf8.encode(password)), nonce: salt);
    return {
      'password_salt': base64Encode(salt),
      'password_hash': base64Encode(await key.extractBytes())
    };
  }

  Future<bool> _verifyPassword(
      String password, Map<String, Object?> user) async {
    final salt = base64Decode(user['password_salt'] as String);
    final expected = base64Decode(user['password_hash'] as String);
    final key = await _kdf.deriveKey(
        secretKey: SecretKey(utf8.encode(password)), nonce: salt);
    final actual = await key.extractBytes();
    if (actual.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < actual.length; i++) {
      difference |= actual[i] ^ expected[i];
    }
    return difference == 0;
  }

  User _user(Map<String, Object?> row) => User.fromJson({
        'id': row['id'].toString(),
        'username': row['username'],
        'email': row['email'],
        'mobile': row['mobile'],
        'role': row['role'],
        'is_active': row['is_active'] == 1,
        'must_change_password': row['must_change_password'] == 1,
        'created_at': row['created_at'],
      });
}
