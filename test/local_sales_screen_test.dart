import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:swiftmart_frontend/providers/app_settings_provider.dart';
import 'package:swiftmart_frontend/providers/auth_provider.dart';
import 'package:swiftmart_frontend/providers/bill_provider.dart';
import 'package:swiftmart_frontend/providers/customer_provider.dart';
import 'package:swiftmart_frontend/providers/product_provider.dart';
import 'package:swiftmart_frontend/screens/pos_screen.dart';

class _BillProvider extends BillProvider {
  @override
  Future<void> loadOpenBills() async {}

  @override
  Future<void> createNewBill(String customerId) async {}
}

void main() {
  testWidgets('standalone sales opens on a phone-sized screen', (tester) async {
    final auth = AuthProvider();
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider<BillProvider>(create: (_) => _BillProvider()),
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
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
