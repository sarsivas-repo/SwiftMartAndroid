import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:swiftmart_frontend/models/models.dart';
import 'package:swiftmart_frontend/providers/app_settings_provider.dart';
import 'package:swiftmart_frontend/providers/auth_provider.dart';
import 'package:swiftmart_frontend/providers/bill_provider.dart';
import 'package:swiftmart_frontend/providers/customer_provider.dart';
import 'package:swiftmart_frontend/providers/product_provider.dart';
import 'package:swiftmart_frontend/providers/reports_provider.dart';
import 'package:swiftmart_frontend/screens/home_screen.dart';
import 'package:swiftmart_frontend/screens/stock_screen.dart';

class _Admin extends AuthProvider {
  @override
  bool get isAdmin => true;
  @override
  Future<void> fetchUsers() async {}
}

class _Cashier extends _Admin {
  @override
  bool get isAdmin => false;
  @override
  bool get isCashier => true;
}

class _Products extends ProductProvider {
  final entries = [
    Product(id: '1', name: 'Rice', sku: 'R01', category: 'Grocery',
        price: 65, quantity: 24, reorderLevel: 5,
        createdAt: DateTime(2026), updatedAt: DateTime(2026)),
    Product(id: '2', name: 'Milk', sku: 'M02', category: 'Dairy',
        price: 28, quantity: 3, reorderLevel: 5,
        createdAt: DateTime(2026), updatedAt: DateTime(2026)),
  ];
  @override
  List<Product> get products => entries;
  @override
  Future<void> fetchProducts() async {}
  @override
  Future<void> fetchLowStockAlerts() async {}
  @override
  Future<void> fetchStockLogs({String? productId}) async {}
}

class _Customers extends CustomerProvider {
  @override
  Future<void> fetchCustomers() async {}
}

class _Bills extends BillProvider {
  @override
  Future<void> loadOpenBills() async {}
  @override
  Future<void> createNewBill(String customerId) async {}
}

class _Reports extends ReportsProvider {
  @override
  Future<void> fetchDailySalesReport(DateTime date) async {}
}

Widget _app(Widget child, {double textScale = 1, bool cashier = false}) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
            create: (_) => cashier ? _Cashier() : _Admin()),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider<ProductProvider>(create: (_) => _Products()),
        ChangeNotifierProvider<CustomerProvider>(create: (_) => _Customers()),
        ChangeNotifierProvider<BillProvider>(create: (_) => _Bills()),
        ChangeNotifierProvider<ReportsProvider>(create: (_) => _Reports()),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: child,
      ),
    );

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('phone navigation keeps management pages accessible', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('New sale'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Users'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    await tester.tap(find.text('Customers'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Search customers...'), findsOneWidget);
    await tester.tap(find.text('Sales'));
    await tester.pumpAndSettle();
    expect(find.text('New sale'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone stock cards can be searched and opened', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const StockScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Search products'), 'm02');
    await tester.pumpAndSettle();
    expect(find.text('Rice'), findsNothing);
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(find.text('Record purchase'), findsOneWidget);
    expect(find.text('Sales tax settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small phone remains usable with larger text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const HomeScreen(), textScale: 1.3));
    await tester.pumpAndSettle();
    expect(find.text('New sale'), findsOneWidget);
    await tester.tap(find.text('Stock'));
    await tester.pumpAndSettle();
    expect(find.text('Rice'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cashier retains sign out without management navigation', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const HomeScreen(), cashier: true));
    await tester.pumpAndSettle();
    expect(find.text('New sale'), findsOneWidget);
    expect(find.byTooltip('Logout'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
