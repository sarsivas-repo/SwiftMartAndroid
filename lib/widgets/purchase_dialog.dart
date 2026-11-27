import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/product_provider.dart';
import '../services/api_service.dart';
import '../utils/app_utils.dart';

class PurchaseDialog extends StatefulWidget {
  const PurchaseDialog({super.key, required this.product});
  final Product product;

  @override
  State<PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<PurchaseDialog> {
  final _requestId = const Uuid().v4();
  String _quantity = '1';
  String _cost = '';
  String _rate = '0';
  String _mode = 'none';
  String _supplier = '';
  String _invoice = '';
  String? _error;
  bool _sending = false;
  bool _attempted = false;

  int? _minor(String input) {
    final match = RegExp(r'^(\d{1,8})(?:\.(\d{1,2}))?$').firstMatch(input.trim());
    if (match == null) return null;
    return int.parse(match.group(1)!) * 100 +
        int.parse((match.group(2) ?? '').padRight(2, '0'));
  }

  String? get _preview {
    final quantity = int.tryParse(_quantity.trim());
    final cost = _minor(_cost);
    final rate = _mode == 'none' ? 0 : _minor(_rate);
    if (quantity == null || quantity <= 0 || quantity > 1000000 || cost == null ||
        rate == null || rate > 10000 || cost > 9999999999 ~/ quantity) {
      return null;
    }
    final amount = cost * quantity;
    final base = _mode == 'inclusive'
        ? (amount * 10000 + (10000 + rate) ~/ 2) ~/ (10000 + rate) : amount;
    final tax = _mode == 'inclusive' ? amount - base :
        _mode == 'additional' ? (amount * rate + 5000) ~/ 10000 : 0;
    if (base + tax > 9999999999) return null;
    return 'Subtotal: ${AppUtils.formatCurrency(base / 100)}   '
        'Tax: ${AppUtils.formatCurrency(tax / 100)}   '
        'Total: ${AppUtils.formatCurrency((base + tax) / 100)}';
  }

  Future<void> _submit() async {
    final quantity = int.tryParse(_quantity.trim());
    final cost = _minor(_cost);
    final rate = _mode == 'none' ? 0 : _minor(_rate);
    if (quantity == null || quantity <= 0 || quantity > 1000000 ||
        cost == null || rate == null || rate > 10000 ||
        cost > 9999999999 ~/ quantity ||
        _supplier.trim().runes.length > 255 || _invoice.trim().runes.length > 255) {
      setState(() => _error = 'Enter a valid quantity, cost and tax rate (0–100%).');
      return;
    }
    final amount = cost * quantity;
    if (_mode == 'additional' && amount + (amount * rate + 5000) ~/ 10000 > 9999999999) {
      setState(() => _error = 'Purchase total is too large.');
      return;
    }
    setState(() { _sending = true; _attempted = true; _error = null; });
    try {
      await ApiService.recordPurchase(productId: widget.product.id,
          requestId: _requestId, quantity: quantity, unitCostMinor: cost,
          taxMode: _mode, taxBasisPoints: rate, supplier: _supplier,
          invoiceReference: _invoice).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final products = context.read<ProductProvider>();
      await products.fetchProducts();
      if (!mounted) return;
      final refreshError = products.error;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(
          refreshError == null ? 'Purchase recorded.' : 'Purchase recorded; stock refresh failed: $refreshError')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Purchase status may be uncertain: $e. Retry unchanged or check stock before starting another purchase.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: AlertDialog(
      title: Text('Record purchase: ${widget.product.name}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter supplier cost, not the selling price or printed MRP.'),
            TextFormField(initialValue: '1', enabled: !_attempted,
                onChanged: (v) => setState(() => _quantity = v), keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity purchased')),
            TextFormField(enabled: !_attempted, onChanged: (v) => setState(() => _cost = v),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Supplier unit price')),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _mode, decoration: const InputDecoration(labelText: 'Purchase tax'),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('No tax recorded')),
                DropdownMenuItem(value: 'inclusive', child: Text('Tax included in unit price')),
                DropdownMenuItem(value: 'additional', child: Text('Tax added to unit price')),
              ],
              onChanged: _attempted ? null : (v) => setState(() => _mode = v!),
            ),
            if (_mode != 'none')
              TextFormField(initialValue: _rate, enabled: !_attempted,
                  onChanged: (v) => setState(() => _rate = v),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Tax rate %')),
            TextFormField(enabled: !_attempted, onChanged: (v) => _supplier = v,
                maxLength: 255, decoration: const InputDecoration(labelText: 'Supplier (optional)')),
            TextFormField(enabled: !_attempted, onChanged: (v) => _invoice = v,
                maxLength: 255, decoration: const InputDecoration(labelText: 'Invoice reference (optional)')),
            if (_preview != null) Text(_preview!),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        )),
      ),
      actions: [
        TextButton(onPressed: _sending ? null : () => Navigator.pop(context),
            child: const Text('Close')),
        FilledButton(onPressed: _sending ? null : _submit,
            child: Text(_attempted ? 'Retry unchanged' : 'Record purchase')),
      ],
    ),
  );
}
