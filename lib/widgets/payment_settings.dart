import 'package:flutter/material.dart';

import '../services/api_service.dart';

class PaymentSettings extends StatefulWidget {
  const PaymentSettings({super.key});

  @override
  State<PaymentSettings> createState() => _PaymentSettingsState();
}

class _PaymentSettingsState extends State<PaymentSettings> {
  bool _loading = true;
  String? _error;
  String? _mode;
  String? _selected;
  List<String> _providers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await ApiService.getPaymentProviderConfig();
      if (!mounted) return;
      final providers = List<String>.from(config['providers'] as List);
      final selected = config['selected_provider'] as String;
      setState(() {
        _mode = config['mode'] as String;
        _providers = providers;
        _selected = providers.contains(selected) ? selected : null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final provider = _selected;
    if (provider == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiService.setPaymentProvider(provider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment provider saved.')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('UPI payment provider',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (_mode != null)
                Text('Server environment: ${_mode!.toUpperCase()}'),
              const Text(
                'Provider credentials are configured securely on the server. '
                'Do not change accounts while payments are pending.',
              ),
              if (_error != null) Text('Payment settings unavailable: $_error'),
              if (_loading) const LinearProgressIndicator(),
              if (!_loading && _error == null) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selected,
                  decoration: const InputDecoration(labelText: 'Provider'),
                  items: _providers
                      .map((provider) => DropdownMenuItem(
                            value: provider,
                            child: Text(provider),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _selected = value),
                ),
                if (_providers.isEmpty)
                  const Text(
                      'No provider credentials are configured on the server.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _selected == null ? null : _save,
                  child: const Text('Save payment provider'),
                ),
              ],
              if (!_loading && _error != null)
                TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
