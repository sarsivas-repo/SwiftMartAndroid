import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:swiftmart_frontend/services/app_license.dart';
import 'package:swiftmart_frontend/services/local_users.dart';
import 'package:swiftmart_frontend/widgets/app_edition_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final vector = jsonDecode(
    File('test/fixtures/license-vector.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final publicKey = base64Decode(vector['public_key'] as String);
  final code = vector['code'] as String;
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('installation trial is 30 days and upgrades never restart it', () async {
    var now = DateTime.utc(2026, 11, 27);
    AppLicense release(String version) => AppLicense(
          licensed: true,
          publicKey: publicKey,
          version: version,
          clock: () => now,
          elapsed: () => Duration.zero,
        );
    final first = release('1.0.8');
    await first.initialize();
    final expiry = first.expiresAt!;
    expect(first.daysRemaining, 30);
    now = expiry.subtract(const Duration(microseconds: 1));
    expect(first.active, isTrue);
    expect(first.daysRemaining, 1);
    now = expiry;
    expect(first.active, isFalse);
    expect(first.requireActive, throwsStateError);
    await first.refresh();
    final reinstalled = release('1.0.8');
    await reinstalled.initialize();
    expect(reinstalled.active, isFalse);
    expect(reinstalled.expiresAt, expiry);
    final next = release('1.0.9');
    await next.initialize();
    expect(next.daysRemaining, 0);
    expect(next.active, isFalse);
    now = now.add(const Duration(days: 30));
    expect(next.active, isFalse);
    final old = release('1.0.8');
    await old.initialize();
    expect(old.active, isFalse);
  });

  test('clock rollback and corrupt stored state block use', () async {
    var now = DateTime.utc(2026, 11, 27);
    final license = AppLicense(
      licensed: true,
      publicKey: publicKey,
      version: '1.0.8',
      clock: () => now,
      elapsed: () => Duration.zero,
    );
    await license.initialize();
    now = now.add(const Duration(hours: 2));
    await license.refresh();
    now = now.subtract(const Duration(hours: 1));
    expect(license.active, isFalse);
    expect(license.blockedReason, contains('clock'));
    SharedPreferences.setMockInitialValues(
        {'swiftmart_license_state': 'broken'});
    final corrupted = AppLicense(
      licensed: true,
      publicKey: publicKey,
      version: '1.0.8',
      clock: () => now,
    );
    await corrupted.initialize();
    expect(corrupted.active, isFalse);
    expect(corrupted.blockedReason, contains('Cannot verify'));
    final development = AppLicense(
      licensed: false,
      version: '1.0.8',
      clock: () => DateTime.utc(2099),
    );
    await development.initialize();
    expect(development.active, isTrue);
    expect(development.expiresAt, isNull);
  });

  test('Go-generated paid license activates, survives updates and is reusable',
      () async {
    var now = DateTime.parse(vector['issued_at'] as String);
    AppLicense open(String version) => AppLicense(
          licensed: true,
          version: version,
          publicKey: publicKey,
          clock: () => now,
          elapsed: () => Duration.zero,
        );
    final first = open('1.0.8');
    await first.initialize();
    now = now.add(const Duration(days: 30));
    expect(first.active, isFalse);
    await first.activate(code);
    expect(first.active, isTrue);
    expect(first.kind, 'paid');
    expect(first.customer, 'Interoperability test only');
    expect(first.expiresAt, DateTime.parse(vector['expires_at'] as String));
    await first.activate(code);
    final updated = open('1.0.9');
    await updated.initialize();
    expect(updated.expiresAt, first.expiresAt);
    expect(updated.kind, 'paid');
    final parts = code.split('.');
    parts[2] =
        '${parts[2].startsWith('A') ? 'B' : 'A'}${parts[2].substring(1)}';
    await expectLater(updated.activate(parts.join('.')), throwsFormatException);
    SharedPreferences.setMockInitialValues({});
    final otherDevice = open('1.0.9');
    await otherDevice.initialize();
    await otherDevice.activate(code);
    expect(otherDevice.expiresAt, first.expiresAt);
    now = first.expiresAt!;
    expect(updated.active, isFalse);
    await expectLater(updated.activate(code), throwsStateError);
  });

  test('expiry blocks standalone login and existing authenticated sessions',
      () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await LocalUsers.createSchema(db);
    var now = DateTime.utc(2026, 11, 27);
    final license = AppLicense(
      licensed: true,
      publicKey: publicKey,
      version: '1.0.8',
      clock: () => now,
      elapsed: () => Duration.zero,
    );
    await license.initialize();
    final users = LocalUsers(db, license: license);
    await users.setupAdmin('admin', 'password123');
    await users.login('admin', 'password123');
    now = now.add(const Duration(days: 30));
    await expectLater(users.currentUser(), throwsStateError);
    await expectLater(users.login('admin', 'password123'), throwsStateError);
    expect((await db.query('local_users')).length, 1);
  });

  testWidgets('open Trial hides login when its 30 days expire', (tester) async {
    var now = DateTime.utc(2026, 11, 27);
    final license = AppLicense(
      licensed: true,
      publicKey: publicKey,
      version: '1.0.8',
      clock: () => now,
      elapsed: () => Duration.zero,
    );
    await license.initialize();
    await tester.pumpWidget(MaterialApp(
      home: AppEditionGate(
        license: license,
        child: const Scaffold(body: Text('Login form')),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Login form'), findsOneWidget);
    expect(find.textContaining('30 days left'), findsOneWidget);
    now = now.add(const Duration(days: 30));
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('Login form'), findsNothing);
    expect(find.textContaining('has expired'), findsOneWidget);
    await tester.enterText(find.byType(TextField), code);
    await tester.tap(find.text('Activate / extend license'));
    await tester.pumpAndSettle();
    expect(find.text('Login form'), findsOneWidget);
    expect(find.textContaining('paid:'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    license.dispose();
  });
}
