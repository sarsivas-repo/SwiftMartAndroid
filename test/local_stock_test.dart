import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:swiftmart_frontend/models/models.dart';
import 'package:swiftmart_frontend/services/api_service.dart';
import 'package:swiftmart_frontend/services/local_stock.dart';
import 'package:swiftmart_frontend/services/local_users.dart';

void main() {
  late Database db;
  late LocalUsers users;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await LocalUsers.createSchema(db);
    await LocalStock.createSchema(db);
    users = LocalUsers(db);
    await users.setupAdmin('admin', 'password123');
    await users.login('admin', 'password123');
    ApiService.configureLocal(users);
  });
  tearDown(() async {
    ApiService.configureServer('https://example.test/api');
    await db.close();
  });

  test('stock updates and audit logs are transactional', () async {
    final product = await ApiService.addProduct('Rice', '001', 'Food', 15, 2);
    expect((await ApiService.getLowStockAlerts()).single.id, product.id);
    await ApiService.restockProduct(product.id, 4, notes: 'Delivery');
    expect((await ApiService.getProducts()).single.quantity, 4);
    expect(await ApiService.getLowStockAlerts(), isEmpty);
    await expectLater(ApiService.updateStock(product.id, -5), throwsStateError);
    expect((await ApiService.getProducts()).single.quantity, 4);
    await ApiService.updateStock(product.id, -2);
    expect((await ApiService.getLowStockAlerts()).single.quantity, 2);
    final logs = await ApiService.getStockLogs(productId: product.id);
    expect(logs.length, 2);
    expect(logs.first.quantity, -2);
    expect(logs.last.notes, 'Delivery');
    await ApiService.updateReorderLevel(product.id, 1);
    expect(await ApiService.getLowStockAlerts(), isEmpty);
  });

  test('cashier can restock but cannot manage products', () async {
    final product = await ApiService.addProduct('Rice', '001', 'Food', 15, 2);
    await users.createUser('cashier', '', 'password123', UserRole.cashier);
    users.logout();
    await users.login('cashier', 'password123');
    await expectLater(
        ApiService.addProduct('Milk', '002', 'Food', 10, 0), throwsStateError);
    await expectLater(ApiService.updateStock(product.id, 1), throwsStateError);
    await ApiService.restockProduct(product.id, 2);
    expect((await ApiService.getProducts()).single.quantity, 2);
  });
}
