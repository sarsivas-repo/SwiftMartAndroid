import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/sandbox_payment.dart';
import '../services/api_service.dart';
import '../utils/app_utils.dart';

abstract class SandboxPaymentClient {
  Future<List<String>> providers();
  Future<List<SandboxPayment>> list();
  Future<SandboxPayment?> forDraft(String draftId);
  Future<SandboxPayment> create({
    required String draftId,
    required String provider,
    required int taxPaise,
    required String customerPhone,
    required String os,
    required String browser,
  });
  Future<SandboxPayment> check(String id);
  Future<SandboxPayment> recoverRazorpay(String id, String reference);
}

class ApiSandboxPaymentClient implements SandboxPaymentClient {
  ApiSandboxPaymentClient({this.mode = 'sandbox'});
  final String mode;

  @override
  Future<List<String>> providers() async {
    final config = await ApiService.getPaymentProviderConfig();
    if (config['mode'] != mode) {
      throw StateError('Payment environment changed. Reopen checkout.');
    }
    return List<String>.from(config['providers'] as List);
  }

  @override
  Future<List<SandboxPayment>> list() => ApiService.getSandboxPayments();

  @override
  Future<SandboxPayment?> forDraft(String draftId) =>
      ApiService.getSandboxPaymentForDraft(draftId);

  @override
  Future<SandboxPayment> create({
    required String draftId,
    required String provider,
    required int taxPaise,
    required String customerPhone,
    required String os,
    required String browser,
  }) =>
      ApiService.createSandboxPayment(
        draftId: draftId,
        provider: provider,
        taxPaise: taxPaise,
        customerPhone: customerPhone,
        os: os,
        browser: browser,
      );

  @override
  Future<SandboxPayment> check(String id) => ApiService.checkSandboxPayment(id);

  @override
  Future<SandboxPayment> recoverRazorpay(String id, String reference) =>
      ApiService.recoverSandboxRazorpayPayment(id, reference);
}

class SandboxPaymentDialog extends StatefulWidget {
  const SandboxPaymentDialog({
    super.key,
    required this.draftId,
    required this.taxPaise,
    required this.client,
    required this.onCompleted,
    this.resumeOnly = false,
    this.estimatedAmountPaise,
    this.mode = 'sandbox',
    this.preferredProvider,
    this.mobile = false,
  });

  final String draftId;
  final int taxPaise;
  final SandboxPaymentClient client;
  final Future<void> Function(SandboxPayment) onCompleted;
  final bool resumeOnly;
  final int? estimatedAmountPaise;
  final String mode;
  final String? preferredProvider;
  final bool mobile;

  @override
  State<SandboxPaymentDialog> createState() => _SandboxPaymentDialogState();
}

class _SandboxPaymentDialogState extends State<SandboxPaymentDialog> {
  final _phone = TextEditingController();
  final _razorpayReference = TextEditingController();
  List<String> _providers = [];
  String? _provider;
  String _os = 'others';
  String _browser = 'others';
  SandboxPayment? _payment;
  Timer? _timer;
  bool _loading = true;
  bool _busy = false;
  bool _allowCreate = false;
  bool _notified = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      final payment = _payment;
      if (!_busy &&
          payment != null &&
          (payment.state == 'ready' ||
              (payment.state == 'creating' &&
                  payment.providerReference != null))) {
        _check();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _razorpayReference.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _allowCreate = false;
    });
    try {
      final providers = await widget.client.providers();
      final payment = await widget.client.forDraft(widget.draftId);
      if (!mounted) return;
      setState(() {
        _providers = providers;
        _provider = providers.contains(widget.preferredProvider)
            ? widget.preferredProvider
            : (widget.mode == 'sandbox' && providers.isNotEmpty
                ? providers.first
                : null);
        _payment = payment;
        _allowCreate = payment == null && !widget.resumeOnly;
        if (payment == null && widget.resumeOnly) {
          _error =
              'The payment is no longer attached to this draft. Check payment history.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Cannot load payment: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (_busy || !_allowCreate || _provider == null) return;
    if (_provider == 'cashfree' &&
        !RegExp(r'^[6-9][0-9]{9}$').hasMatch(_phone.text.trim())) {
      setState(() =>
          _error = 'Cashfree requires a valid 10-digit customer phone number.');
      return;
    }
    setState(() {
      _busy = true;
      _allowCreate = false;
      _error = null;
    });
    try {
      final payment = await widget.client.create(
        draftId: widget.draftId,
        provider: _provider!,
        taxPaise: widget.taxPaise,
        customerPhone: _phone.text.trim(),
        os: _os,
        browser: _browser,
      );
      if (!mounted) return;
      setState(() => _payment = payment);
      await _notifyCompleted(payment);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Payment creation could not be confirmed: $error. '
          'Do not collect another payment; reload to check the existing attempt.');
      try {
        final payment = await widget.client.forDraft(widget.draftId);
        if (mounted && payment != null) {
          setState(() => _payment = payment);
        }
      } catch (lookupError) {
        if (mounted) {
          setState(() => _error = 'Payment outcome is unknown: $lookupError. '
              'Do not collect another payment; reconcile this draft.');
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    final payment = _payment;
    if (_busy || payment == null || payment.state == 'completed') return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final checked = await widget.client.check(payment.id);
      if (!mounted) return;
      setState(() => _payment = checked);
      await _notifyCompleted(checked);
    } on SandboxPaymentException catch (error) {
      if (!mounted) return;
      setState(() {
        _payment = error.payment ?? _payment;
        _error = error.message;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Payment status is unknown: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _notifyCompleted(SandboxPayment payment) async {
    if (payment.state != 'completed' || _notified) return;
    if (payment.billId == null) {
      throw const FormatException('Completed payment has no bill number');
    }
    _notified = true;
    await widget.onCompleted(payment);
  }

  Future<void> _recoverRazorpay() async {
    final payment = _payment;
    if (_busy ||
        payment == null ||
        payment.provider != 'razorpay' ||
        payment.state != 'creating' ||
        payment.providerReference != null) {
      return;
    }
    final reference = _razorpayReference.text.trim();
    if (reference.isEmpty) {
      setState(
          () => _error = 'Enter the Razorpay QR ID to recover this payment.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final recovered =
          await widget.client.recoverRazorpay(payment.id, reference);
      if (!mounted) return;
      setState(() => _payment = recovered);
      await _notifyCompleted(recovered);
    } on SandboxPaymentException catch (error) {
      if (!mounted) return;
      setState(() {
        _payment = error.payment ?? _payment;
        _error = error.message;
      });
      if (error.payment != null) {
        await _notifyCompleted(error.payment!);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            'Recovery could not be confirmed: $error. Do not collect another payment.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _qr(SandboxPayment payment) {
    final value = payment.qrValue;
    if (value == null) {
      return const Text('QR is unavailable. Check the payment status.');
    }
    if (payment.qrFormat == 'upi_uri') {
      return QrImageView(data: value, size: 220, backgroundColor: Colors.white);
    }
    if (payment.qrFormat == 'data_uri' &&
        value.startsWith('data:image/png;base64,')) {
      try {
        return Image.memory(
            base64Decode(value.substring('data:image/png;base64,'.length)),
            width: 220,
            height: 220,
            errorBuilder: (_, __, ___) =>
                const Text('Could not display the QR image.'));
      } on FormatException {
        return const Text('Invalid QR image; check the payment status.');
      }
    }
    if (payment.qrFormat == 'image_url') {
      final uri = Uri.tryParse(value);
      if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
        return Image.network(value,
            width: 220,
            height: 220,
            errorBuilder: (_, __, ___) => const Text(
                'Could not load the provider QR image. Check the payment status.'));
      }
    }
    return const Text('Invalid QR response; check the payment status.');
  }

  @override
  Widget build(BuildContext context) {
    final payment = _payment;
    return AlertDialog(
      title: Text(widget.mode == 'live'
          ? 'UPI payment - LIVE'
          : 'UPI payment - SANDBOX ONLY'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.mode == 'live'
                  ? 'Real payments. Confirm status with the provider before retrying.'
                  : 'Test transactions only. Do not collect real payments.'),
              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(),
              if (!_loading && payment == null && _allowCreate) ...[
                if (widget.estimatedAmountPaise != null)
                  Text(
                      'Estimated total: ${AppUtils.formatCurrency(widget.estimatedAmountPaise! / 100)} '
                      '(final amount calculated by the server).'),
                if (_providers.isEmpty)
                  const Text('No payment provider is configured on the server.')
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _provider,
                    decoration: const InputDecoration(labelText: 'Provider'),
                    items: _providers
                        .map((value) =>
                            DropdownMenuItem(value: value, child: Text(value)))
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _provider = value),
                  ),
                  if (_provider == null)
                    const Text(
                        'Select a provider in payment settings or choose one here.'),
                  if (_provider == 'cashfree') ...[
                    TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                            labelText: 'Customer phone (10 digits)')),
                    if (!widget.mobile)
                      DropdownButtonFormField<String>(
                        initialValue: _os,
                        decoration: const InputDecoration(
                            labelText: 'Checkout device OS'),
                        items: const ['windows', 'linux', 'macos', 'others']
                            .map((value) => DropdownMenuItem(
                                value: value, child: Text(value)))
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _os = value!),
                      ),
                    if (!widget.mobile)
                      DropdownButtonFormField<String>(
                        initialValue: _browser,
                        decoration: const InputDecoration(labelText: 'Browser'),
                        items: const [
                          'chrome',
                          'edge',
                          'firefox',
                          'safari',
                          'others'
                        ]
                            .map((value) => DropdownMenuItem(
                                value: value, child: Text(value)))
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _browser = value!),
                      ),
                  ],
                ],
              ],
              if (payment != null) ...[
                Text(
                    'Amount: ${AppUtils.formatCurrency(payment.amountPaise / 100)}'),
                Text('Provider: ${payment.provider}'),
                Text('Reference: ${payment.providerReference ?? payment.id}'),
                const SizedBox(height: 12),
                if (payment.state == 'ready') ...[
                  const Text('Waiting for provider confirmation.'),
                  const SizedBox(height: 12),
                  Center(child: _qr(payment)),
                ] else if (payment.state == 'creating')
                  const Text(
                      'Payment creation outcome is unknown. Do not collect another payment.')
                else if (payment.state == 'verified')
                  const Text(
                      'Payment confirmed, but the bill is not complete. Resolve the issue and retry.')
                else if (payment.state == 'completed')
                  Text('Payment confirmed. Bill #${payment.billId} completed.'),
                if (payment.provider == 'razorpay' &&
                    payment.state == 'creating' &&
                    payment.providerReference == null) ...[
                  const SizedBox(height: 12),
                  const Text(
                      'Find the QR ID in Razorpay records or contact Razorpay support. '
                      'The server will verify it against this attempt before checking payment.'),
                  TextField(
                    controller: _razorpayReference,
                    enabled: !_busy,
                    decoration:
                        const InputDecoration(labelText: 'Razorpay QR ID'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy ? null : _recoverRazorpay,
                    child: const Text('Recover Razorpay payment'),
                  ),
                ],
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Close')),
        if (!_loading && payment == null && !_allowCreate)
          TextButton(
              onPressed: _busy ? null : _load, child: const Text('Reload')),
        if (!_loading &&
            payment == null &&
            _allowCreate &&
            _providers.isNotEmpty)
          FilledButton(
              onPressed: _busy ? null : _create,
              child: const Text('Generate QR')),
        if (payment != null && payment.state != 'completed')
          FilledButton(
              onPressed: _busy ? null : _check,
              child: Text(payment.state == 'verified'
                  ? 'Retry bill completion'
                  : 'Check status')),
      ],
    );
  }
}

class SandboxPaymentHistoryDialog extends StatefulWidget {
  const SandboxPaymentHistoryDialog({
    super.key,
    required this.client,
    required this.onOpenDraft,
    this.mode = 'sandbox',
  });

  final SandboxPaymentClient client;
  final void Function(SandboxPayment) onOpenDraft;
  final String mode;

  @override
  State<SandboxPaymentHistoryDialog> createState() =>
      _SandboxPaymentHistoryDialogState();
}

class _SandboxPaymentHistoryDialogState
    extends State<SandboxPaymentHistoryDialog> {
  late Future<List<SandboxPayment>> _payments;

  @override
  void initState() {
    super.initState();
    _payments = widget.client.list();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.mode == 'live'
            ? 'Live payment history'
            : 'Sandbox payment history'),
        content: SizedBox(
          width: 520,
          child: FutureBuilder<List<SandboxPayment>>(
            future: _payments,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Text('Could not load payments: ${snapshot.error}');
              }
              final payments = snapshot.requireData;
              if (payments.isEmpty) return const Text('No payments.');
              return SizedBox(
                height: 360,
                child: ListView.builder(
                  itemCount: payments.length,
                  itemBuilder: (context, index) {
                    final payment = payments[index];
                    return ListTile(
                      title: Text(
                          '${payment.provider} - ${AppUtils.formatCurrency(payment.amountPaise / 100)}'),
                      subtitle: Text(
                          'Reference: ${payment.providerReference ?? payment.id}\n'
                          'Status: ${payment.state}${payment.billId == null ? '' : ' | Bill #${payment.billId}'}'),
                      isThreeLine: true,
                      trailing: payment.draftId != null &&
                              payment.state != 'completed'
                          ? TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onOpenDraft(payment);
                              },
                              child: const Text('Open'),
                            )
                          : null,
                    );
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      );
}
