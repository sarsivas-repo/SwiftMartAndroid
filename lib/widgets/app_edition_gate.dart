import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_license.dart';

class AppEditionGate extends StatefulWidget {
  const AppEditionGate({super.key, required this.child, required this.license});

  final Widget child;
  final AppLicense license;

  @override
  State<AppEditionGate> createState() => _AppEditionGateState();
}

class _AppEditionGateState extends State<AppEditionGate>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _settings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.license.licensed) {
      _timer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => widget.license.refresh(),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.license.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.license,
        builder: (context, _) {
          final license = widget.license;
          final reason = license.blockedReason;
          if (reason != null || _settings) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('License settings'),
                leading: reason == null
                    ? BackButton(
                        onPressed: () => setState(() => _settings = false))
                    : null,
              ),
              body: LicenseSettings(license: license),
            );
          }
          final label = license.licensed
              ? 'License valid until ${license.expiresAt!.toIso8601String().substring(0, 10)} UTC'
              : 'Development build';
          return Column(
            children: [
              Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Text(
                            'SwiftMart ${license.version} | $label\nPublisher: Saravanakumar',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          if (license.licensed)
                            TextButton(
                              onPressed: () => setState(() => _settings = true),
                              child: const Text('License settings'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: widget.child),
            ],
          );
        },
      );
}

class LicenseSettings extends StatefulWidget {
  const LicenseSettings({super.key, required this.license});

  final AppLicense license;

  @override
  State<LicenseSettings> createState() => _LicenseSettingsState();
}

class _LicenseSettingsState extends State<LicenseSettings> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.license.activate(_code.text);
      if (mounted) {
        _code.clear();
        setState(() => _message = 'License activated.');
      }
    } catch (error) {
      if (mounted) setState(() => _message = 'Activation failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.license,
        builder: (context, _) {
          final license = widget.license;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Publisher: Saravanakumar'),
              Text(
                'Version: ${license.version} | License: ${license.kind == 'trial' ? 'Initial license' : license.kind}',
              ),
              if (license.customer != null)
                Text('Customer: ${license.customer}'),
              SelectableText(
                'Expires (UTC): ${license.expiresAt?.toIso8601String() ?? 'Not available'}',
              ),
              Text('Days remaining: ${license.daysRemaining}'),
              if (license.licenseID != null)
                SelectableText('License ID: ${license.licenseID}'),
              const SizedBox(height: 16),
              if (license.blockedReason != null)
                Text(license.blockedReason!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              const Text(
                'Send the expiry above to Saravanakumar to request a paid extension. Your business data is preserved; do not uninstall or clear app data.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _code,
                minLines: 3,
                maxLines: 6,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'License code'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _activate,
                child:
                    Text(_busy ? 'Activating...' : 'Activate / extend license'),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_message!),
                ),
            ],
          );
        },
      );
}
