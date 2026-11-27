import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/server_settings.dart';

class ServerSetupScreen extends StatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  final _address = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    String normalized;
    try {
      normalized = ServerSettings.normalizeAddress(_address.text);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
      return;
    }
    if (Uri.parse(normalized).scheme == 'http') {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unencrypted connection'),
          content: const Text(
            'HTTP exposes passwords and business data on the network. Use HTTPS unless you understand and accept this risk.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Use HTTP')),
          ],
        ),
      );
      if (approved != true || !mounted) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<ServerSettings>().save(normalized);
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Unable to save server address: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Connect to SwiftMart')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
                'Enter the address of your SwiftMart server. Use HTTPS when possible.'),
            const SizedBox(height: 20),
            TextField(
              controller: _address,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Server address',
                hintText: 'https://your-server.example',
                errorText: _error ?? context.watch<ServerSettings>().error,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Continue')),
          ],
        ),
      );
}
