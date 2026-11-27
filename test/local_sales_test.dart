import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:swiftmart_frontend/models/models.dart';
import 'package:swiftmart_frontend/services/api_service.dart';
import 'package:swiftmart_frontend/services/local_sales.dart';
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
    await LocalSales.createSchema(db);
    users = LocalUsers(db);
    await users.setupAdmin('admin', 'password123');
    await users.login('admin', 'password123');
    ApiService.configureLocal(users);
  });
  tearDown(() async {
    ApiService.configureServer('https://example.test/api');
    await db.close();
  });

  test('draft checkout records a sale and decrements stock exactly once',
      () async {
    final product = await ApiService.addProduct('Rice', '001', 'Food', 15, 2);
    await ApiService.restockProduct(product.id, 5);
    final customer =
        await ApiService.registerCustomer('Customer', '', '123', '');
    var draft = await ApiService.createDraftBill(int.parse(customer.id));
    draft = await ApiService.addItemToDraftBill(draft.id, product.id, 2);
    expect(draft.subtotal, 30);
    final checkout = await ApiService.checkoutDraftBill(draft.id, 3, 'card');
    expect(checkout['total'], 33);
    expect((await ApiService.getProducts()).single.quantity, 3);
    expect(await ApiService.getDraftBills(), isEmpty);
    expect((await ApiService.getCustomers()).single.totalSpent, 33);
    final history = await ApiService.getCustomerHistory(customer.id);
    expect(history, hasLength(1));
    expect(history.single.id, checkout['bill_id'].toString());
    expect(history.single.taxAmount, 3);
    expect(history.single.paymentMethod, 'card');
    expect(history.single.items.single.productName, 'Rice');
    expect(history.single.items.single.quantity, 2);
    await expectLater(
        ApiService.checkoutDraftBill(draft.id, 3, 'cash'), throwsStateError);
    expect((await ApiService.getProducts()).single.quantity, 3);
  });

  test('checkout rejects insufficient stock without changing any product',
      () async {
    final first = await ApiService.addProduct('Rice', '001', 'Food', 15, 2);
    final second = await ApiService.addProduct('Milk', '002', 'Food', 10, 2);
    await ApiService.restockProduct(first.id, 5);
    await ApiService.restockProduct(second.id, 5);
    final draft = await ApiService.createDraftBill(null);
    await ApiService.addItemToDraftBill(draft.id, first.id, 3);
    await ApiService.addItemToDraftBill(draft.id, second.id, 3);
    await ApiService.addDirectItemToDraftBill(draft.id, 'Eggs', 2, 650);
    await ApiService.updateStock(second.id, -3);
    await expectLater(
        ApiService.checkoutDraftBill(draft.id, 0, 'cash'), throwsStateError);
    final products = await ApiService.getProducts();
    expect(products.firstWhere((p) => p.id == first.id).quantity, 5);
    expect(products.firstWhere((p) => p.id == second.id).quantity, 2);
    expect((await ApiService.getDraftBills()).single.items.length, 3);
    expect(await db.query('local_bills'), isEmpty);
    expect(await db.query('local_direct_bill_items'), isEmpty);
    expect(await db.query('local_direct_draft_items'), hasLength(1));
  });

  test('direct and stocked items retain snapshots without changing direct stock', () async {
    final product = await ApiService.addProduct('Rice', '001', 'Food', 15, 2);
    await ApiService.restockProduct(product.id, 5);
    final customer = await ApiService.registerCustomer('Customer', '', '', '');
    var draft = await ApiService.createDraftBill(int.parse(customer.id));
    draft = await ApiService.addDirectItemToDraftBill(draft.id, 'Eggs', 10, 650);
    final directId = draft.items.single.id;
    expect(directId, startsWith('direct:'));
    draft = await ApiService.updateDraftItemQuantity(draft.id, directId, 8);
    draft = await ApiService.addItemToDraftBill(draft.id, product.id, 2);
    expect(draft.subtotal, 82);
    expect((await ApiService.getDraftBills()).single.items.length, 2);
    final checkout = await ApiService.checkoutDraftBill(draft.id, 0, 'cash');
    expect(checkout['total'], 82);
    expect((await ApiService.getProducts()).single.quantity, 3);
    final history = await ApiService.getCustomerHistory(customer.id);
    expect(history.single.items.firstWhere((item) => item.productName == 'Eggs').quantity, 8);
    expect(await db.query('local_direct_draft_items'), isEmpty);
    expect(await db.query('local_direct_bill_items'), hasLength(1));
  });

  test('direct items can be removed and respect draft ownership', () async {
    final draft = await ApiService.createDraftBill(null);
    final updated = await ApiService.addDirectItemToDraftBill(draft.id, 'Eggs', 1, 100);
    final directId = updated.items.single.id;
    await users.createUser('cashier', '', 'password123', UserRole.cashier);
    users.logout();
    await users.login('cashier', 'password123');
    await expectLater(ApiService.removeItemFromDraftBill(draft.id, directId), throwsStateError);
    users.logout();
    await users.login('admin', 'password123');
    expect((await ApiService.removeItemFromDraftBill(draft.id, directId)).items, isEmpty);
  });

  test('drafts are private to each cashier', () async {
    await users.createUser('cashier', '', 'password123', UserRole.cashier);
    final draft = await ApiService.createDraftBill(null);
    users.logout();
    await users.login('cashier', 'password123');
    expect(await ApiService.getDraftBills(), isEmpty);
    await expectLater(ApiService.deleteDraftBill(draft.id), throwsStateError);
    users.logout();
    await users.login('admin', 'password123');
    expect((await ApiService.getDraftBills()).single.id, draft.id);
  });
}
