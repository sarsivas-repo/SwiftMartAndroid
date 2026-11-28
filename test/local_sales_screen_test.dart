import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:swiftmart_frontend/models/models.dart';
import 'package:swiftmart_frontend/providers/app_settings_provider.dart';
import 'package:swiftmart_frontend/providers/auth_provider.dart';
import 'package:swiftmart_frontend/providers/bill_provider.dart';
import 'package:swiftmart_frontend/providers/customer_provider.dart';
import 'package:swiftmart_frontend/providers/product_provider.dart';
import 'package:swiftmart_frontend/screens/pos_screen.dart';
import 'package:swiftmart_frontend/services/api_service.dart';
import 'package:swiftmart_frontend/services/local_users.dart';

class _BillProvider extends BillProvider {
  String? added;
  @override
  Future<void> loadOpenBills() async {}

  @override
  Future<void> createNewBill(String customerId) async {}

  @override
  Future<bool> addDirectItem(String name, int quantity, int pricePaise,
      {String taxMode = 'none', int taxBasisPoints = 0}) async {
    added = '$name:$quantity:$pricePaise:$taxMode:$taxBasisPoints';
    return true;
  }
}

class _ReceiptBills extends _BillProvider {
  final sample = Bill(
    id: '1', customerId: 'guest', subtotal: 13, taxAmount: 0, total: 13,
    status: BillStatus.completed, paymentMethod: 'cash',
    createdAt: DateTime(2026),
    items: [BillItem(id: '1', billId: '1', productId: '1',
        productName: 'Eggs', price: 6.5, quantity: 2, subtotal: 13)],
  );
  @override
  Bill get currentBill => sample;
  @override
  List<Bill> get openBills => [sample];
  @override
  List<Bill> get bills => [sample];
  @override
  Future<bool> checkout(double paidAmount, String paymentMethod) async => true;
}

class _ProductBills extends _BillProvider {
  String? productAdded;
  final draft = Bill(
    id: '1', customerId: 'guest', subtotal: 0, taxAmount: 0, total: 0,
    status: BillStatus.pending, paymentMethod: 'cash',
    createdAt: DateTime(2026), items: const [],
  );
  @override
  Bill get currentBill => draft;
  @override
  List<Bill> get openBills => [draft];
  @override
  Future<bool> addItemToCurrentBill(String productId, int quantity) async {
    productAdded = '$productId:$quantity';
    return true;
  }
}

class _Products extends ProductProvider {
  @override
  List<Product> get products => [
    Product(id: 'rice', name: 'Rice', sku: 'R01', category: 'Grocery',
        price: 65, quantity: 24, reorderLevel: 5,
        createdAt: DateTime(2026), updatedAt: DateTime(2026)),
  ];
}

void main() {
  late Database db;
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting();
  });
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  });
  tearDown(() async {
    ApiService.configureServer('https://example.test/api');
    await db.close();
  });
  testWidgets('standalone sales opens on a phone-sized screen', (tester) async {
    final auth = AuthProvider();
    final bills = _BillProvider();
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider<BillProvider>.value(value: bills),
      ],
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(
              title: const Text('Standalone test preview'),
              bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(48),
                  child: SizedBox(height: 48))),
          body: const Column(children: [
            Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                    'Standalone test data stays on this phone. Salary and reports are not implemented.')),
            Text('admin · Admin'),
            Expanded(child: POSScreen()),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Sell without stock'),
      200,
      scrollable: find.descendant(
        of: find.byType(POSScreen),
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.tap(find.text('Sell without stock'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Item name'), 'Eggs');
    await tester.enterText(find.widgetWithText(TextFormField, 'Quantity'), '10');
    await tester.enterText(find.widgetWithText(TextFormField, 'Price per item'), '6.50');
    await tester.tap(find.text('No tax recorded / final price').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add tax separately').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Tax rate %'), '5.25');
    await tester.tap(find.widgetWithText(FilledButton, 'Add item'));
    await tester.pumpAndSettle();
    expect(bills.added, 'Eggs:10:650:additional:525');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('standalone receipt shares itemized text without printing', (tester) async {
    ApiService.configureLocal(LocalUsers(db));
    final calls = <MethodCall>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('com.swiftmart/share'),
        (call) async { calls.add(call); return null; });
    messenger.setMockMethodCallHandler(const MethodChannel('com.swiftmart/printing'),
        (call) async { calls.add(call); return null; });
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    final bills = _ReceiptBills();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider<BillProvider>.value(value: bills),
      ],
      child: const MaterialApp(home: POSScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Checkout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();
    expect(find.text('Receipt Preview'), findsOneWidget);
    await tester.tap(find.text('Share receipt'));
    await tester.pumpAndSettle();
    expect(calls.single.method, 'shareReceipt');
    expect(calls.single.arguments.toString(), contains('Eggs: 2 x'));
    expect(calls.single.arguments.toString(), contains('Total:'));
    await tester.tap(find.text('Print / Save PDF'));
    await tester.pumpAndSettle();
    expect(calls.last.method, 'printReceipt');
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(calls, hasLength(2));
    await tester.pumpWidget(const SizedBox());
    messenger.setMockMethodCallHandler(const MethodChannel('com.swiftmart/share'), null);
    messenger.setMockMethodCallHandler(const MethodChannel('com.swiftmart/printing'), null);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('phone sales can select a product and add a quantity', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bills = _ProductBills();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider<ProductProvider>(create: (_) => _Products()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider<BillProvider>.value(value: bills),
      ],
      child: const MaterialApp(home: POSScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Product'), 'R01');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rice'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Quantity'), '2');
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    expect(bills.productAdded, 'rice:2');
    expect(tester.takeException(), isNull);
  });
}
