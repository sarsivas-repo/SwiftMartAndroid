import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/bill_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/product_provider.dart';
import '../services/server_settings.dart';
import 'user_management_screen.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';
import 'stock_screen.dart';
import 'pos_screen.dart';
import 'customers_screen.dart';

class LocalAccountScreen extends StatefulWidget {
  const LocalAccountScreen({super.key});

  @override
  State<LocalAccountScreen> createState() => _LocalAccountScreenState();
}

class _LocalAccountScreenState extends State<LocalAccountScreen> {
  final _username = TextEditingController(text: 'admin');
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late Future<bool> _needsSetup;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _needsSetup = context.read<ServerSettings>().localUsers!.needsSetup;
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    if (_password.text != _confirmation.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context
          .read<ServerSettings>()
          .localUsers!
          .setupAdmin(_username.text, _password.text);
      if (mounted) setState(() => _needsSetup = Future.value(false));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: _needsSetup,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
                body: Center(
                    child:
                        Text('Cannot open test accounts: ${snapshot.error}')));
          }
          if (!snapshot.hasData) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (!snapshot.data!) {
            final auth = context.watch<AuthProvider>();
            if (!auth.isLoggedIn) return const LoginScreen();
            if (auth.shouldPromptPasswordChange)
              return const ChangePasswordScreen();
            return MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => BillProvider()),
                ChangeNotifierProvider(create: (_) => ProductProvider()),
                ChangeNotifierProvider(create: (_) => CustomerProvider()),
              ],
              child: const _LocalHome(),
            );
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Standalone test setup')),
            body: ListView(padding: const EdgeInsets.all(24), children: [
              const Text(
                  'Create the administrator for this phone. These accounts are separate from the server.'),
              TextField(
                  controller: _username,
                  decoration: const InputDecoration(
                      labelText: 'Administrator username')),
              TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Password (at least 8 characters)')),
              TextField(
                  controller: _confirmation,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Confirm password')),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: _busy ? null : _setup,
                  child: const Text('Create administrator')),
              TextButton(
                  onPressed: _busy
                      ? null
                      : () => context.read<ServerSettings>().edit(),
                  child: const Text('Back')),
            ]),
          );
        },
      );
}

class _LocalHome extends StatefulWidget {
  const _LocalHome();

  @override
  State<_LocalHome> createState() => _LocalHomeState();
}

class _LocalHomeState extends State<_LocalHome> {
  int _selectedPage = 0;
  bool _showMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.isAdmin || auth.isCashier) {
        context.read<ProductProvider>().fetchProducts();
        context.read<CustomerProvider>().fetchCustomers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tabs = <Tab>[
      if (auth.isAdmin || auth.isCashier) const Tab(text: 'Sales'),
      if (auth.isAdmin || auth.isManager) const Tab(text: 'Stock'),
      if (auth.isAdmin) const Tab(text: 'Customers'),
      if (auth.isAdmin) const Tab(text: 'Users'),
    ];
    final screens = <Widget>[
      if (auth.isAdmin || auth.isCashier) const POSScreen(),
      if (auth.isAdmin || auth.isManager) const StockScreen(),
      if (auth.isAdmin) const CustomersScreen(),
      if (auth.isAdmin) const UserManagementScreen(),
    ];
    if (MediaQuery.sizeOf(context).width < 600 && screens.isNotEmpty) {
      final primary = <int>[
        for (var i = 0; i < tabs.length; i++)
          if (tabs[i].text == 'Sales' || tabs[i].text == 'Stock') i,
      ];
      final more = <int>[
        for (var i = 0; i < tabs.length; i++)
          if (!primary.contains(i)) i,
      ];
      final selectedPage = _selectedPage < screens.length ? _selectedPage : 0;
      final selectedPrimary = primary.indexOf(selectedPage);
      final showMore = _showMore && more.isNotEmpty;
      return Scaffold(
        appBar: AppBar(
          title: const Text('SwiftMart'),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              onPressed: auth.logout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: Column(children: [
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.secondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text('Standalone: data stays on this phone.'),
          ),
          Expanded(
            child: showMore
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('More', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      Card(child: Column(children: [
                        ...more.map((index) => ListTile(
                              leading: Icon(tabs[index].text == 'Customers'
                                  ? Icons.people_outline
                                  : Icons.manage_accounts_outlined),
                              title: Text(tabs[index].text!),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => setState(() {
                                _selectedPage = index;
                                _showMore = false;
                              }),
                            )),
                      ])),
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Salary and reports are not available in standalone mode.'),
                      ),
                    ],
                  )
                : screens[selectedPage],
          ),
        ]),
        bottomNavigationBar: primary.length + (more.isNotEmpty ? 1 : 0) < 2
            ? null
            : NavigationBar(
                selectedIndex:
                    more.isNotEmpty && (showMore || selectedPrimary < 0)
                        ? primary.length
                        : selectedPrimary,
                onDestinationSelected: (index) => setState(() {
                  if (index == primary.length) {
                    _showMore = true;
                  } else {
                    _showMore = false;
                    _selectedPage = primary[index];
                  }
                }),
                destinations: [
                  ...primary.map((index) => NavigationDestination(
                        icon: Icon(tabs[index].text == 'Sales'
                            ? Icons.shopping_cart_outlined
                            : Icons.inventory_2_outlined),
                        label: tabs[index].text!,
                      )),
                  if (more.isNotEmpty)
                    const NavigationDestination(
                        icon: Icon(Icons.more_horiz), label: 'More'),
                ],
              ),
      );
    }
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Standalone test preview'),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              onPressed: () => auth.logout(),
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: tabs.isEmpty
              ? null
              : TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: tabs),
        ),
        body: Column(children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
                'Standalone test data stays on this phone. Salary and reports are not implemented.'),
          ),
          Text(
              '${auth.user?.username ?? ''} · ${auth.user?.roleSummary ?? ''}'),
          Expanded(
            child: screens.isEmpty
                ? const Center(
                    child: Text('Signed in with the selected test role.'))
                : TabBarView(children: screens),
          ),
        ]),
      ),
    );
  }
}
