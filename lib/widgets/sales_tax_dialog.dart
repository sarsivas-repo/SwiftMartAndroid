import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/product_provider.dart';
import '../services/api_service.dart';

class SalesTaxDialog extends StatefulWidget {
  const SalesTaxDialog({super.key, required this.product});
  final Product product;

  @override
  State<SalesTaxDialog> createState() => _SalesTaxDialogState();
}

class _SalesTaxDialogState extends State<SalesTaxDialog> {
  late String mode = widget.product.taxMode;
  late String rate = (widget.product.taxBasisPoints / 100).toStringAsFixed(2);
  late String mrp = widget.product.mrpMinor == null
      ? ''
      : (widget.product.mrpMinor! / 100).toStringAsFixed(2);
  bool saving = false;
  String? error;

  int? minor(String value) {
    final match = RegExp(r'^(\d{1,8})(?:\.(\d{1,2}))?$').firstMatch(value.trim());
    if (match == null) return null;
    return int.parse(match.group(1)!) * 100 +
        int.parse((match.group(2) ?? '').padRight(2, '0'));
  }

  Future<void> save() async {
    final basisPoints = mode == 'none' ? 0 : minor(rate);
    final limit = mrp.trim().isEmpty ? null : minor(mrp);
    if (basisPoints == null || basisPoints > 10000 ||
        (mrp.trim().isNotEmpty && limit == null)) {
      setState(() => error = 'Enter a tax rate from 0 to 100 and a valid optional MRP.');
      return;
    }
    setState(() { saving = true; error = null; });
    try {
      await ApiService.updateProductPricing(widget.product.id, mode, basisPoints, limit);
      if (!mounted) return;
      final products = context.read<ProductProvider>();
      await products.fetchProducts();
      if (!mounted) return;
      if (products.error != null) {
        setState(() { saving = false; error = 'Saved, but refresh failed: ${products.error}'; });
        return;
      }
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { saving = false; error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Sales tax: ${widget.product.name}'),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: mode,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Selling price treatment'),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('No tax recorded / final price')),
              DropdownMenuItem(value: 'inclusive', child: Text('Tax included in price')),
              DropdownMenuItem(value: 'additional', child: Text('Add tax separately')),
            ],
            onChanged: saving ? null : (value) => setState(() => mode = value!),
          ),
          if (mode != 'none')
            TextFormField(
              initialValue: rate,
              enabled: !saving,
              onChanged: (value) => rate = value,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Tax rate %'),
            ),
          TextFormField(
            initialValue: mrp,
            enabled: !saving,
            onChanged: (value) => mrp = value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Maximum final price / MRP (optional)'),
          ),
          const SizedBox(height: 12),
          const Text('Changes apply when an item is first added to a new bill. Existing bill lines keep their original price and tax.'),
          if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      )),
    ),
    actions: [
      TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: saving ? null : save, child: const Text('Save')),
    ],
  );
}
