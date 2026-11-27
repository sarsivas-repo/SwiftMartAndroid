import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/server_settings.dart';
import 'user_management_screen.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';
import 'stock_screen.dart';

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
            return const _LocalHome();
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

class _LocalHome extends StatelessWidget {
  const _LocalHome();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tabs = <Tab>[
      if (auth.isAdmin || auth.isManager) const Tab(text: 'Stock'),
      if (auth.isAdmin) const Tab(text: 'Users'),
    ];
    final screens = <Widget>[
      if (auth.isAdmin || auth.isManager) const StockScreen(),
      if (auth.isAdmin) const UserManagementScreen(),
    ];
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
          bottom: tabs.isEmpty ? null : TabBar(tabs: tabs),
        ),
        body: Column(children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
                'Test accounts and stock only. Sales, customers and reports are not implemented.'),
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
