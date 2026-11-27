import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:swiftmart_frontend/models/models.dart';
import 'package:swiftmart_frontend/services/api_service.dart';
import 'package:swiftmart_frontend/services/local_users.dart';

void main() {
  late Database db;
  late LocalUsers users;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await LocalUsers.createSchema(db);
    users = LocalUsers(db);
  });
  tearDown(() => db.close());

  test('setup, login, and role-based user management', () async {
    expect(await users.needsSetup, isTrue);
    await users.setupAdmin('admin', 'password123');
    expect(await users.needsSetup, isFalse);
    await expectLater(
        users.setupAdmin('other', 'password123'), throwsStateError);
    await expectLater(users.login('admin', 'wrong'), throwsStateError);
    expect((await users.login('admin', 'password123')).role, UserRole.admin);
    final manager =
        await users.createUser('manager', '', 'password123', UserRole.manager);
    final cashier =
        await users.createUser('cashier', '', 'password123', UserRole.cashier);
    expect((await users.listUsers()).length, 3);
    await expectLater(
      users.updateUser('1',
          username: 'admin',
          email: '',
          mobile: '',
          role: UserRole.cashier,
          active: true),
      throwsStateError,
    );
    users.logout();
    expect(
        (await users.login('manager', 'password123')).role, UserRole.manager);
    await expectLater(
        users.createUser('bad', '', 'password123', UserRole.admin),
        throwsStateError);
    await expectLater(users.listUsers(), throwsStateError);
    users.logout();
    expect(
        (await users.login('cashier', 'password123')).role, UserRole.cashier);
    users.logout();
    await users.login('admin', 'password123');
    await users.updateUser(manager.id,
        username: manager.username,
        email: '',
        mobile: '',
        role: UserRole.manager,
        active: false);
    await users.deleteUser(cashier.id);
    users.logout();
    await expectLater(users.login('manager', 'password123'), throwsStateError);
    await expectLater(users.login('cashier', 'password123'), throwsStateError);
  });

  test('password change and reset persist without plaintext passwords',
      () async {
    await users.setupAdmin('admin', 'password123');
    await users.login('admin', 'password123');
    final staff =
        await users.createUser('staff', '', 'password123', UserRole.cashier);
    final stored =
        (await db.query('local_users', where: 'id = ?', whereArgs: [staff.id]))
            .single;
    expect(stored['password_hash'], isNot(contains('password123')));
    await users.resetPassword(staff.id, 'newpassword123');
    users.logout();
    await expectLater(users.login('staff', 'password123'), throwsStateError);
    expect((await users.login('staff', 'newpassword123')).mustChangePassword,
        isTrue);
    await expectLater(
        users.changePassword('wrong', 'anotherpassword'), throwsStateError);
    await users.changePassword('newpassword123', 'anotherpassword');
    users.logout();
    expect((await users.login('staff', 'anotherpassword')).mustChangePassword,
        isFalse);
  });
  test('API routes test accounts to the isolated local database', () async {
    await users.setupAdmin('admin', 'password123');
    ApiService.configureLocal(users);
    final login = await ApiService.login('admin', 'password123');
    expect((login['user'] as Map)['role'], 'admin');
    final staff = await ApiService.createUser(
        'cashier', 'cashier@example.test', 'password123', [UserRole.cashier]);
    expect(staff.role, UserRole.cashier);
    expect((await ApiService.getUsers()).length, 2);
    await ApiService.logout();
    await expectLater(ApiService.getUsers(), throwsStateError);
    await ApiService.login('cashier', 'password123');
    await expectLater(ApiService.getUsers(), throwsStateError);
    ApiService.configureServer('https://example.test/api');
  });
}
