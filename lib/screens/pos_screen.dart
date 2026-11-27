import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/product_provider.dart';
import '../providers/bill_provider.dart';
import '../providers/customer_provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/product_widgets.dart';
import '../utils/app_utils.dart';
import '../utils/constants.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({Key? key}) : super(key: key);

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  static const String _guestCustomerId = 'guest';
  static const String _guestCustomerName = 'Guest Customer';
  static const double _controlHeight = 56;
  static const double _actionButtonSize = 40;
  static const double _userBadgeHeight = 44;
  static const double _controlRadius = 8;
  static const BorderSide _enabledBorderSide =
      BorderSide(color: Color(0xFFBDBDBD));
  static const BorderSide _focusedBorderSide =
      BorderSide(color: Color(0xFF1976D2), width: 1.5);

  late TextEditingController _customerController;
  late FocusNode _customerFocusNode;
  late TextEditingController _skuController;
  late TextEditingController _quantityController;
  late FocusNode _skuFocusNode;
  late ScrollController _billScrollController;
  String? _selectedCustomerId;
  String? _selectedProductId;
  String? _lockedSelectedProductName;
  bool _showSkuSuggestions = false;
  bool _showCustomerSuggestions = false;
  bool _selectingSuggestion = false;
  bool _selectingCustomerSuggestion = false;
  bool _isProgrammaticSkuUpdate = false;
  bool _isProgrammaticCustomerUpdate = false;
  bool _isTypingCustomerSearch = false;

  @override
  void initState() {
    super.initState();
    _customerController = TextEditingController(text: _guestCustomerName);
    _customerFocusNode = FocusNode();
    _skuController = TextEditingController();
    _quantityController = TextEditingController(text: '1');
    _skuFocusNode = FocusNode();
    _billScrollController = ScrollController();

    _customerFocusNode.addListener(() {
      if (_customerFocusNode.hasFocus) {
        _isTypingCustomerSearch = true;
      }

      if (!_customerFocusNode.hasFocus && mounted) {
        Future.delayed(const Duration(milliseconds: 280), () {
          if (!mounted) {
            return;
          }
          if (_selectingCustomerSuggestion) {
            _selectingCustomerSuggestion = false;
            return;
          }
          _isTypingCustomerSearch = false;
          setState(() => _showCustomerSuggestions = false);
        });
      }
    });

    _skuFocusNode.addListener(() {
      if (!_skuFocusNode.hasFocus && mounted) {
        // Give pointer events enough time on web so suggestion tap-down selection wins.
        Future.delayed(const Duration(milliseconds: 320), () {
          if (!mounted) {
            return;
          }
          if (_selectingSuggestion) {
            _selectingSuggestion = false;
            return;
          }
          setState(() => _showSkuSuggestions = false);
        });
      }
    });

    Future.microtask(() {
      final billProvider = context.read<BillProvider>();
      billProvider.loadOpenBills().then((_) async {
        if (!mounted) {
          return;
        }
        if (billProvider.currentBill == null) {
          await billProvider.createNewBill(_guestCustomerId);
        }
        if (!mounted) {
          return;
        }
        _syncSelectedCustomerFromCurrentBill(
          billProvider,
          context.read<CustomerProvider>(),
        );
      });
    });
  }

  @override
  void dispose() {
    _customerController.dispose();
    _customerFocusNode.dispose();
    _skuController.dispose();
    _quantityController.dispose();
    _skuFocusNode.dispose();
    _billScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Consumer4<AuthProvider, CustomerProvider, ProductProvider, BillProvider>(
              builder: (context, authProvider, customerProvider, productProvider, billProvider, _) {
                _syncSelectedCustomerFromCurrentBill(billProvider, customerProvider);
                final customerSuggestions = _getMatchingCustomers(
                  customerProvider.customers,
                  _customerController.text,
                );
                final suggestions = _getMatchingProducts(
                  productProvider.products,
                  _skuController.text,
                );
                final cashierOnly =
                    authProvider.isCashier && !authProvider.isAdmin && !authProvider.isManager;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compactLayout = constraints.maxWidth < 1150;

                            final leftControls = SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 230,
                                    height: _controlHeight,
                                    child: TextField(
                                      controller: _customerController,
                                      focusNode: _customerFocusNode,
                                      decoration: InputDecoration(
                                        labelText: 'Customer',
                                        hintText: 'Guest Customer / Search / Add',
                                        prefixIcon: const Icon(Icons.person_search),
                                        suffixIcon: _customerController.text.isEmpty
                                            ? null
                                            : IconButton(
                                                tooltip: 'Clear customer search',
                                                onPressed: _clearCustomerSearch,
                                                icon: const Icon(Icons.close),
                                              ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(_controlRadius),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(_controlRadius),
                                          borderSide: _enabledBorderSide,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(_controlRadius),
                                          borderSide: _focusedBorderSide,
                                        ),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                      ),
                                      onTap: () {
                                        if (_customerController.text.trim().isNotEmpty) {
                                          setState(() => _showCustomerSuggestions = true);
                                        }
                                      },
                                      onChanged: (value) {
                                        if (_isProgrammaticCustomerUpdate) {
                                          return;
                                        }
                                        setState(() {
                                          _selectedCustomerId = null;
                                          _showCustomerSuggestions = true;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 330,
                                    height: _controlHeight,
                                    child: TextField(
                                      controller: _skuController,
                                      focusNode: _skuFocusNode,
                                      decoration: InputDecoration(
                                        labelText: 'Product',
                                        floatingLabelBehavior: FloatingLabelBehavior.always,
                                        hintText: 'Scan or search product',
                                        prefixIcon: const Icon(Icons.search),
                                        suffixIcon: _skuController.text.isEmpty
                                            ? null
                                            : IconButton(
                                                onPressed: () {
                                                  setState(() {
                                                    _skuController.clear();
                                                    _selectedProductId = null;
                                                    _lockedSelectedProductName = null;
                                                    _showSkuSuggestions = false;
                                                  });
                                                },
                                                icon: const Icon(Icons.close),
                                              ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(_controlRadius),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(_controlRadius),
                                          borderSide: _enabledBorderSide,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(_controlRadius),
                                          borderSide: _focusedBorderSide,
                                        ),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                      ),
                                      onTap: () {
                                        if (_lockedSelectedProductName != null) {
                                          setState(() {
                                            _lockedSelectedProductName = null;
                                            _selectedProductId = null;
                                          });
                                        }
                                        if (_skuController.text.trim().isNotEmpty) {
                                          setState(() => _showSkuSuggestions = true);
                                        }
                                      },
                                      onChanged: (value) {
                                        if (_lockedSelectedProductName != null &&
                                            value != _lockedSelectedProductName) {
                                          final lockedName = _lockedSelectedProductName!;
                                          _skuController.value = TextEditingValue(
                                            text: lockedName,
                                            selection: TextSelection.collapsed(
                                              offset: lockedName.length,
                                            ),
                                          );
                                          return;
                                        }

                                        if (_isProgrammaticSkuUpdate) {
                                          return;
                                        }
                                        setState(() {
                                          _selectedProductId = null;
                                          _showSkuSuggestions = value.trim().isNotEmpty;
                                        });
                                      },
                                      onSubmitted: (_) => _addItemToBill(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 110,
                                    height: _controlHeight,
                                    child: TextField(
                                      controller: _quantityController,
                                      keyboardType: TextInputType.number,
                                      onSubmitted: (_) => _addItemToBill(),
                                      decoration: InputDecoration(
                                        labelText: 'Quantity',
                                        floatingLabelBehavior: FloatingLabelBehavior.always,
                                        hintText: 'Qty',
                                        constraints: BoxConstraints.tightFor(height: _controlHeight),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(_controlRadius),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(_controlRadius),
                                          borderSide: _enabledBorderSide,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(_controlRadius),
                                          borderSide: _focusedBorderSide,
                                        ),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Consumer<BillProvider>(
                                    builder: (context, billProvider, _) {
                                      return SizedBox(
                                        width: 230,
                                        height: _controlHeight,
                                        child: _ActiveBillDropdown(
                                          openBills: billProvider.openBills,
                                          activeBillId: billProvider.activeBillId,
                                          customerProvider: customerProvider,
                                          onSelectBill: (billId) async {
                                            await billProvider.switchToBill(billId);
                                            if (!mounted) {
                                              return;
                                            }
                                            _syncSelectedCustomerFromCurrentBill(
                                              billProvider,
                                              customerProvider,
                                            );
                                          },
                                          onRemoveBill: (billId) async {
                                            final removed = await billProvider.closeBill(billId);
                                            if (!mounted) {
                                              return;
                                            }
                                            if (!removed) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    billProvider.error ?? 'Unable to remove active bill',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            if (billProvider.currentBill == null) {
                                              await billProvider.createNewBill(_guestCustomerId);
                                            }

                                            _syncSelectedCustomerFromCurrentBill(
                                              billProvider,
                                              customerProvider,
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Consumer<BillProvider>(
                                    builder: (context, billProvider, _) {
                                      return Tooltip(
                                        message: 'Add item',
                                        child: SizedBox(
                                          height: _actionButtonSize,
                                          width: _actionButtonSize,
                                          child: Material(
                                            color: AppConstants.primaryColor,
                                            borderRadius: BorderRadius.circular(_controlRadius),
                                            child: InkWell(
                                              onTap: billProvider.isLoading ? null : _addItemToBill,
                                              borderRadius: BorderRadius.circular(_controlRadius),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(_controlRadius),
                                                  border: const Border.fromBorderSide(_enabledBorderSide),
                                                ),
                                                alignment: Alignment.center,
                                                child: billProvider.isLoading
                                                    ? const SizedBox(
                                                        height: 18,
                                                        width: 18,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : const Icon(
                                                        Icons.add,
                                                        size: 22,
                                                        color: Colors.white,
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Consumer<BillProvider>(
                                    builder: (context, billProvider, _) {
                                      final canCheckout = billProvider.currentItemCount > 0;
                                      return Tooltip(
                                        message: 'Checkout',
                                        child: SizedBox(
                                          height: _actionButtonSize,
                                          width: _actionButtonSize,
                                          child: Material(
                                            color: canCheckout ? Colors.green : Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(_controlRadius),
                                            child: InkWell(
                                              onTap: canCheckout
                                                  ? () => _showCheckoutDialog(context)
                                                  : null,
                                              borderRadius: BorderRadius.circular(_controlRadius),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(_controlRadius),
                                                  border: const Border.fromBorderSide(_enabledBorderSide),
                                                ),
                                                alignment: Alignment.center,
                                                child: Icon(
                                                  Icons.shopping_cart_checkout,
                                                  size: 22,
                                                  color: canCheckout ? Colors.white : Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );

                            final rightControls = Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (cashierOnly)
                                  SizedBox(
                                    height: _userBadgeHeight,
                                    child: _CashierInlineBadge(
                                      authProvider: authProvider,
                                      onProfileTap: () => _showCashierProfileDialog(),
                                    ),
                                  ),
                              ],
                            );

                            if (compactLayout) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  leftControls,
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: rightControls,
                                  ),
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: leftControls),
                                const SizedBox(width: 12),
                                rightControls,
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    if (_showCustomerSuggestions) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: 450,
                        constraints: const BoxConstraints(maxHeight: 240),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.person_outline),
                              title: const Text(_guestCustomerName),
                              onTap: _selectGuestCustomer,
                            ),
                            ...customerSuggestions.map((customer) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: ListTile(
                                        dense: true,
                                        title: Text(customer.name),
                                        subtitle: Text('${customer.phone} | ${customer.email}'),
                                        onTap: () => _selectCustomer(customer),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      tooltip: 'Edit customer',
                                      onPressed: () => _showEditCustomerDialogPOS(customer),
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.person_add_alt_1, color: Colors.blue),
                              title: Text(
                                _customerController.text.trim().isEmpty
                                    ? 'Add Customer'
                                    : 'Add "${_customerController.text.trim()}" as Customer',
                              ),
                              onTap: () => _showAddCustomerDialog(
                                initialName: _customerController.text.trim(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_showSkuSuggestions && suggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: 700,
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: suggestions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final product = suggestions[index];
                            final outOfStock = product.quantity == 0;
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (_) {
                                _selectingSuggestion = true;
                                _selectProduct(product);
                              },
                              child: ListTile(
                                dense: true,
                                title: Text(
                                  '${product.sku}: ${product.name}',
                                  style: TextStyle(
                                    color: outOfStock ? Colors.red.shade700 : null,
                                    fontWeight: outOfStock ? FontWeight.w600 : null,
                                  ),
                                ),
                                subtitle: Text(
                                  'Stock: ${product.quantity} | ${AppUtils.formatCurrency(product.price)}',
                                  style: TextStyle(
                                    color: outOfStock ? Colors.red.shade700 : null,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Consumer<BillProvider>(
                builder: (context, billProvider, _) {
                  if (billProvider.currentBill == null ||
                      billProvider.currentBill!.items.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Scrollbar(
                    controller: _billScrollController,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _billScrollController,
                      itemCount: billProvider.currentBill!.items.length,
                      itemBuilder: (context, index) {
                        final item = billProvider.currentBill!.items[index];
                        return BillItemCard(
                          item: item,
                          onRemove: () async {
                            final removed = await billProvider.removeItemFromBill(item.id);
                            if (!removed && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(billProvider.error ?? 'Unable to remove item.'),
                              ));
                            }
                          },
                          onUpdateQuantity: () {
                            _showUpdateQuantityDialog(item);
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Consumer<BillProvider>(
              builder: (context, billProvider, _) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          OutlinedButton.icon(
                            onPressed: billProvider.isLoading ? null : _showDirectSaleDialog,
                            icon: const Icon(Icons.add_shopping_cart),
                            label: const Text('Sell without stock'),
                          ),
                          FilledButton.icon(
                            onPressed: billProvider.currentItemCount > 0 && !billProvider.isLoading
                                ? () => _showCheckoutDialog(context) : null,
                            icon: const Icon(Icons.shopping_cart_checkout),
                            label: const Text('Checkout'),
                          ),
                        ],
                      ),
                      _TotalRow(
                        label: 'Subtotal',
                        value: AppUtils.formatCurrency(billProvider.currentSubtotal),
                      ),
                      const SizedBox(height: 8),
                      _TotalRow(
                        label: billProvider.currentBill?.pricingVersion == 0 ? 'Tax (older bill)' : 'Tax',
                        value: AppUtils.formatCurrency(billProvider.currentTax),
                      ),
                      const Divider(height: 16),
                      _TotalRow(
                        label: 'Total',
                        value: AppUtils.formatCurrency(billProvider.currentTotal),
                        isBold: true,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDirectSaleDialog() async {
    var name = '';
    var quantity = '1';
    var price = '';
    var taxMode = 'none';
    var taxRate = '0';
    String? error;
    var saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Sell without stock'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('This item will not change inventory.'),
                TextFormField(onChanged: (value) => name = value, maxLength: 255,
                    decoration: const InputDecoration(labelText: 'Item name')),
                TextFormField(initialValue: '1', onChanged: (value) => quantity = value,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity')),
                TextFormField(onChanged: (value) => price = value,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Price per item')),
                DropdownButtonFormField<String>(
                  initialValue: taxMode,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Sales tax'),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('No tax recorded / final price')),
                    DropdownMenuItem(value: 'inclusive', child: Text('Tax included in price')),
                    DropdownMenuItem(value: 'additional', child: Text('Add tax separately')),
                  ],
                  onChanged: saving ? null : (value) => setDialogState(() => taxMode = value!),
                ),
                if (taxMode != 'none')
                  TextFormField(initialValue: taxRate,
                      onChanged: (value) => taxRate = value,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Tax rate %')),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving ? null : () async {
                final count = int.tryParse(quantity.trim());
                final match = RegExp(r'^(\d{1,8})(?:\.(\d{1,2}))?$')
                    .firstMatch(price.trim());
                final rateMatch = RegExp(r'^(\d{1,3})(?:\.(\d{1,2}))?$')
                    .firstMatch(taxRate.trim());
                final rate = taxMode == 'none' ? 0 : rateMatch == null ? null :
                    int.parse(rateMatch.group(1)!) * 100 +
                    int.parse((rateMatch.group(2) ?? '').padRight(2, '0'));
                if (name.trim().isEmpty || count == null ||
                    count <= 0 || count > 1000000 || match == null ||
                    rate == null || rate > 10000) {
                  setDialogState(() => error =
                      'Enter a name, quantity, valid price and tax rate (0–100%).');
                  return;
                }
                final paise = int.parse(match.group(1)!) * 100 +
                    int.parse((match.group(2) ?? '').padRight(2, '0'));
                setDialogState(() { saving = true; error = null; });
                final bills = context.read<BillProvider>();
                final success = await bills.addDirectItem(name.trim(), count, paise,
                    taxMode: taxMode, taxBasisPoints: rate);
                if (!dialogContext.mounted) return;
                if (success) {
                  Navigator.pop(dialogContext);
                } else {
                  setDialogState(() { saving = false; error = bills.error ?? 'Unable to add item.'; });
                }
              },
              child: const Text('Add item'),
            ),
          ],
        ),
      ),
    );
  }

  void _addItemToBill() async {
    final sku = _skuController.text.trim();
    final quantityStr = _quantityController.text.trim();

    if (sku.isEmpty || quantityStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter product code and quantity')),
      );
      return;
    }

    final productProvider = context.read<ProductProvider>();
    Product? product;

    if (_selectedProductId != null) {
      product = productProvider.getProductById(_selectedProductId!);
    }

    product ??= _findProductForInput(productProvider.products, sku);

    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product not found. Select a product from the search list.')),
      );
      return;
    }

    final quantity = int.tryParse(quantityStr) ?? 1;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid quantity')),
      );
      return;
    }

    final billProvider = context.read<BillProvider>();
    if (billProvider.currentBill == null) {
      await billProvider.createNewBill(_selectedCustomerId ?? 'guest');
      if (billProvider.currentBill == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to create a new bill. Please try again.')),
        );
        return;
      }
    }
    if (billProvider.currentBill!.pricingVersion == 0 && product.taxMode != 'none') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('This older bill cannot apply product tax. Start a new bill.')));
      }
      return;
    }

    final success = await billProvider.addItemToCurrentBill(
          product.id,
          quantity,
        );

    if (success) {
      _skuController.clear();
      _quantityController.text = '1';
      setState(() {
        _selectedProductId = null;
        _lockedSelectedProductName = null;
        _showSkuSuggestions = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} added to bill')),
      );
    } else {
      final errorMessage = billProvider.error ?? 'Unable to add item. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  void _showUpdateQuantityDialog(BillItem item) {
    final qtyController = TextEditingController(text: item.quantity.toString());

    Future<void> submitUpdate(BuildContext dialogContext) async {
      final newQty = int.tryParse(qtyController.text.trim());
      if (newQty == null || newQty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid quantity')),
        );
        return;
      }

      Navigator.pop(dialogContext);

      final success = await context
          .read<BillProvider>()
          .updateItemQuantityInBill(item.id, newQty);

      if (!mounted) {
        return;
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quantity updated')),
        );
      } else {
        final message = context.read<BillProvider>().error ?? 'Failed to update quantity';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update Quantity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.productName),
            const SizedBox(height: 10),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              onSubmitted: (_) => submitUpdate(dialogContext),
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => submitUpdate(dialogContext),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  List<Customer> _getMatchingCustomers(List<Customer> customers, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty || normalizedQuery == _guestCustomerName.toLowerCase()) {
      return customers.take(8).toList();
    }

    return customers
        .where(
          (customer) =>
              customer.name.toLowerCase().contains(normalizedQuery) ||
              customer.phone.contains(normalizedQuery) ||
              customer.email.toLowerCase().contains(normalizedQuery),
        )
        .take(8)
        .toList();
  }

  void _selectGuestCustomer() async {
    _isProgrammaticCustomerUpdate = true;
    _customerController.text = _guestCustomerName;
    _customerController.selection = TextSelection.collapsed(
      offset: _customerController.text.length,
    );

    setState(() {
      _selectedCustomerId = _guestCustomerId;
      _showCustomerSuggestions = false;
      _selectingCustomerSuggestion = false;
    });

    await _activateOrCreateBillForCustomer(_guestCustomerId);
    if (!mounted) {
      return;
    }
    _syncSelectedCustomerFromCurrentBill(
      context.read<BillProvider>(),
      context.read<CustomerProvider>(),
    );
    _customerFocusNode.unfocus();

    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) {
        return;
      }
      _isProgrammaticCustomerUpdate = false;
    });
  }

  void _clearCustomerSearch() {
    _isProgrammaticCustomerUpdate = true;
    setState(() {
      _selectedCustomerId = null;
      _customerController.clear();
      _showCustomerSuggestions = true;
    });
    _customerFocusNode.requestFocus();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) {
        return;
      }
      _isProgrammaticCustomerUpdate = false;
    });
  }

  void _selectCustomer(Customer customer) async {
    _isProgrammaticCustomerUpdate = true;
    _customerController.text = customer.name;
    _customerController.selection = TextSelection.collapsed(
      offset: _customerController.text.length,
    );

    setState(() {
      _selectedCustomerId = customer.id;
      _showCustomerSuggestions = false;
      _selectingCustomerSuggestion = false;
    });

    await _activateOrCreateBillForCustomer(customer.id);
    if (!mounted) {
      return;
    }
    _syncSelectedCustomerFromCurrentBill(
      context.read<BillProvider>(),
      context.read<CustomerProvider>(),
    );
    _customerFocusNode.unfocus();

    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) {
        return;
      }
      _isProgrammaticCustomerUpdate = false;
    });
  }

  void _showAddCustomerDialog({String initialName = ''}) {
    _selectingCustomerSuggestion = true;
    _showCustomerSuggestions = false;
    final nameController = TextEditingController(text: initialName);
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final phone = phoneController.text.trim();
              final address = addressController.text.trim();

              if (name.isEmpty || email.isEmpty || phone.isEmpty || address.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all customer details')),
                );
                return;
              }

              final provider = context.read<CustomerProvider>();
              final success = await provider.registerCustomer(name, email, phone, address);

              if (!mounted) {
                return;
              }

              if (success) {
                final added = provider.currentCustomer;
                Navigator.pop(dialogContext);
                if (added != null) {
                  _selectCustomer(added);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Customer added successfully')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(provider.error ?? 'Failed to add customer')),
                );
              }
            },
            child: const Text('Save Customer'),
          ),
        ],
      ),
    ).then((_) {
      _selectingCustomerSuggestion = false;
    });
  }

  void _showEditCustomerDialogPOS(Customer customer) {
    _selectingCustomerSuggestion = true;
    _showCustomerSuggestions = false;
    final nameController = TextEditingController(text: customer.name);
    final emailController = TextEditingController(text: customer.email);
    final phoneController = TextEditingController(text: customer.phone);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final phone = phoneController.text.trim();

              if (name.isEmpty || email.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all customer details')),
                );
                return;
              }

              final provider = context.read<CustomerProvider>();
              final success = await provider.updateCustomer(
                customer.id,
                name,
                email,
                phone,
              );

              if (!mounted) {
                return;
              }

              if (success) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Customer updated successfully')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(provider.error ?? 'Failed to update customer')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) {
      _selectingCustomerSuggestion = false;
    });
  }

  List<Product> _getMatchingProducts(List<Product> products, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    return products
        .where(
          (product) =>
              product.sku.toLowerCase().contains(normalizedQuery) ||
              product.name.toLowerCase().contains(normalizedQuery),
        )
        .take(8)
        .toList();
  }

  Product? _findProductForInput(List<Product> products, String input) {
    final normalizedInput = input.trim().toLowerCase();
    if (normalizedInput.isEmpty) {
      return null;
    }

    for (final product in products) {
      if (product.sku.toLowerCase() == normalizedInput ||
          product.name.toLowerCase() == normalizedInput) {
        return product;
      }
    }

    final partialMatches = _getMatchingProducts(products, normalizedInput);
    if (partialMatches.length == 1) {
      return partialMatches.first;
    }

    return null;
  }

  void _selectProduct(Product product) {
    _lockedSelectedProductName = product.name;
    _isProgrammaticSkuUpdate = true;
    _applySelectedProductText(product.name);

    setState(() {
      _selectedProductId = product.id;
      _quantityController.text = '1';
      _showSkuSuggestions = false;
      _selectingSuggestion = false;
    });

    // Re-apply text once more after frame to guard against delayed web IME updates.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lockedSelectedProductName == null) {
        return;
      }
      final lockedName = _lockedSelectedProductName!;
      _applySelectedProductText(lockedName);
    });

    // Apply once more after a short delay for web IME/input lag.
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted || _lockedSelectedProductName == null) {
        return;
      }
      _applySelectedProductText(_lockedSelectedProductName!);
    });

    // Move user to quantity entry after selection and avoid stale IME updates.
    _skuFocusNode.unfocus();
    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) {
        return;
      }
      _isProgrammaticSkuUpdate = false;
    });
  }

  void _applySelectedProductText(String productName) {
    _skuController.value = TextEditingValue(
      text: productName,
      selection: TextSelection.collapsed(offset: productName.length),
      composing: TextRange.empty,
    );
  }

  void _showCheckoutDialog(BuildContext context) {
    var paymentMethod = 'cash';
    var submitting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Checkout'),
        content: Consumer<BillProvider>(
          builder: (context, billProvider, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total: ${AppUtils.formatCurrency(billProvider.currentTotal)}'),
                const SizedBox(height: 16),
                DropdownButton<String>(
                  isExpanded: true,
                  value: paymentMethod,
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'card', child: Text('Card')),
                    DropdownMenuItem(value: 'mobile', child: Text('Mobile')),
                  ],
                  onChanged: submitting ? null : (value) {
                    if (value != null) setDialogState(() => paymentMethod = value);
                  },
                ),
                if (billProvider.error != null)
                  Text(billProvider.error!, style: const TextStyle(color: Colors.red)),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: submitting ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: submitting ? null : () async {
              setDialogState(() => submitting = true);
              final billProvider = context.read<BillProvider>();
              final customerProvider = context.read<CustomerProvider>();
              final productProvider = context.read<ProductProvider>();
              final billBeforeCheckout = billProvider.currentBill;
              final customerSnapshot = billBeforeCheckout == null ||
                      billBeforeCheckout.customerId == _guestCustomerId ||
                      billBeforeCheckout.customerId.trim().isEmpty
                  ? null
                  : customerProvider.getCustomerById(billBeforeCheckout.customerId);
              final success = await billProvider.checkout(
                billProvider.currentTotal,
                paymentMethod,
              );

              if (success && mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Checkout successful')),
                );
                if (context.mounted) Navigator.pop(context);

                _showReceiptDialog(billProvider.bills.first, customerSnapshot);
                productProvider.fetchProducts();
                customerProvider.fetchCustomers();

                if (billProvider.currentBill == null) {
                  await billProvider.createNewBill(_guestCustomerId);
                }
                if (!mounted) return;
                _syncSelectedCustomerFromCurrentBill(
                  billProvider,
                  customerProvider,
                );
              } else if (mounted && context.mounted) {
                setDialogState(() => submitting = false);
              }
            },
            child: const Text('Complete'),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _showReceiptDialog(Bill bill, Customer? customer) async {
    final receiptHtml = _buildReceiptHtml(bill, customer);
    bool sendSms = false;
    bool sendEmail = false;
    bool sending = false;
    bool smsAttempted = false;
    bool emailAttempted = false;
    String? smsStatus;
    String? emailStatus;
    String? availabilityError;

    bool smsProviderEnabled = false;
    bool emailProviderEnabled = false;
    if (!ApiService.isLocal) {
      try {
        final providerConfig = await ApiService.getNotificationAvailability()
            .timeout(const Duration(seconds: 8));
        smsProviderEnabled = providerConfig['sms_enabled'] == true;
        emailProviderEnabled = providerConfig['email_enabled'] == true;
      } catch (e) {
        availabilityError = 'Could not load notification availability: $e';
      }
    }
    if (!mounted) return;

    final customerName = customer?.name.trim().isNotEmpty == true
        ? customer!.name
        : _guestCustomerName;
    final customerPhone = customer?.phone.trim().isNotEmpty == true
        ? customer!.phone
        : '-';
    final customerEmail = customer?.email.trim().isNotEmpty == true
      ? customer!.email
      : '-';
    final hasPhone = customerPhone != '-';
    final hasEmail = customerEmail != '-';
    final canUseSms = hasPhone && smsProviderEnabled;
    final canUseEmail = hasEmail && emailProviderEnabled;
    final customerAddress = customer?.address.trim().isNotEmpty == true
        ? customer!.address
        : '-';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => PopScope(
          canPop: !sending,
          child: AlertDialog(
          title: const Text('Receipt Preview'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppUtils.shopName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text('Bill No: ${bill.id}'),
                  Text('Date: ${_formatDateTime(bill.createdAt)}'),
                  const SizedBox(height: 8),
                  Text('Customer: $customerName'),
                  Text('Mobile: $customerPhone'),
                  Text('Email: $customerEmail'),
                  Text('Address: $customerAddress'),
                  const Divider(height: 20),
                  ...bill.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(
                              item.taxDescription.isEmpty ? item.productName : '${item.productName} (${item.taxDescription})',
                              maxLines: 2, overflow: TextOverflow.ellipsis)),
                          Text('${item.quantity} x ${AppUtils.formatCurrency(item.price)}'),
                          const SizedBox(width: 10),
                          Text(AppUtils.formatCurrency(item.subtotal)),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal'),
                      Text(AppUtils.formatCurrency(bill.subtotal)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tax'),
                      Text(AppUtils.formatCurrency(bill.taxAmount)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        AppUtils.formatCurrency(bill.total),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  if (availabilityError != null)
                    Text(availabilityError!, style: const TextStyle(color: Colors.red)),
                  if (smsStatus != null) Text(smsStatus!),
                  if (emailStatus != null) Text(emailStatus!),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Send SMS to customer'),
                    subtitle: Text(
                      ApiService.isLocal
                          ? 'SMS is unavailable in standalone mode'
                          : !smsProviderEnabled
                          ? 'SMS provider disabled in Settings'
                          : (hasPhone ? customerPhone : 'No mobile number available'),
                    ),
                    value: canUseSms ? sendSms : false,
                    onChanged: canUseSms && !sending && !smsAttempted ? (value) {
                      setDialogState(() {
                        sendSms = value ?? false;
                      });
                    } : null,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Send Email to customer'),
                    subtitle: Text(
                      ApiService.isLocal
                          ? 'Email is unavailable in standalone mode'
                          : !emailProviderEnabled
                          ? 'Email provider disabled in Settings'
                          : (hasEmail ? customerEmail : 'No email available'),
                    ),
                    value: canUseEmail ? sendEmail : false,
                    onChanged: canUseEmail && !sending && !emailAttempted ? (value) {
                      setDialogState(() {
                        sendEmail = value ?? false;
                      });
                    } : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: sending ? null : () => _openPrintDialog(receiptHtml),
              child: const Text('Print / Save PDF'),
            ),
            TextButton(
              onPressed: sending ? null : () async {
                try {
                  await const MethodChannel('com.swiftmart/share').invokeMethod<void>(
                      'shareReceipt', _buildCustomerMessage(bill, customerName));
                  if (dialogContext.mounted) {
                    setDialogState(() => availabilityError =
                        'Choose a messaging app and recipient. Sending is not confirmed.');
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    setDialogState(() => availabilityError = 'Unable to open sharing: $e');
                  }
                }
              },
              child: const Text('Share receipt'),
            ),
            ElevatedButton(
              onPressed: sending || (!sendSms && !sendEmail) ? null : () async {
                setDialogState(() => sending = true);
                final message = _buildCustomerMessage(bill, customerName);

                if (sendSms) {
                  smsAttempted = true;
                    try {
                      await ApiService.sendBillSms(
                        to: customerPhone,
                        message: message,
                        billId: bill.id,
                        customerName: customerName,
                        total: bill.total,
                      ).timeout(const Duration(seconds: 15));
                      smsStatus = 'SMS accepted by provider; delivery is not confirmed.';
                    } catch (e) {
                      smsStatus = 'SMS status uncertain: $e. Check before sending again.';
                    }
                  sendSms = false;
                }

                if (sendEmail) {
                  emailAttempted = true;
                    try {
                      await ApiService.sendBillEmail(
                        to: customerEmail,
                        subject: 'Your receipt from ${AppUtils.shopName} - Bill ${bill.id}',
                        message: message,
                        billId: bill.id,
                        customerName: customerName,
                        total: bill.total,
                      ).timeout(const Duration(seconds: 15));
                      emailStatus = 'Email accepted by provider; delivery is not confirmed.';
                    } catch (e) {
                      emailStatus = 'Email status uncertain: $e. Check before sending again.';
                    }
                  sendEmail = false;
                }
                if (dialogContext.mounted) setDialogState(() => sending = false);
              },
              child: const Text('Send selected'),
            ),
          ],
          ),
        ),
      ),
    );
  }

  String _buildCustomerMessage(Bill bill, String customerName) {
    final lines = bill.items.map((item) =>
        '${item.productName}: ${item.quantity} x ${AppUtils.formatCurrency(item.price)}'
        '${item.taxDescription.isEmpty ? '' : ' (${item.taxDescription})'}'
        ' = ${AppUtils.formatCurrency(item.subtotal)}');
    return '${AppUtils.shopName}\nBill ${bill.id} - ${_formatDateTime(bill.createdAt)}'
        '\nCustomer: $customerName\n${lines.join('\n')}'
        '\nSubtotal: ${AppUtils.formatCurrency(bill.subtotal)}'
        '\nTax: ${AppUtils.formatCurrency(bill.taxAmount)}'
        '\nTotal: ${AppUtils.formatCurrency(bill.total)}';
  }

  String _buildReceiptHtml(Bill bill, Customer? customer) {
    final appSettings = context.read<AppSettingsProvider>();
    final hasShopDetails = appSettings.hasConfiguredShopName;
    final shopName = hasShopDetails ? appSettings.shopName : '';
    final shopEmail = hasShopDetails ? appSettings.shopEmail.trim() : '';
    final shopMobile = hasShopDetails ? appSettings.shopMobile.trim() : '';
    final shopDetailsHtml = hasShopDetails
        ? '''
        <div class="rule"></div>
        <div class="shop">
          <div class="shop-label">Sales Receipt</div>
          <h2>${_escapeHtml(shopName)}</h2>
          ${shopEmail.isNotEmpty ? '<div class="shop-sub">${_escapeHtml(shopEmail)}</div>' : ''}
          ${shopMobile.isNotEmpty ? '<div class="shop-sub">${_escapeHtml(shopMobile)}</div>' : ''}
        </div>
        <div class="rule"></div>
        '''
        : '''
        <div class="rule"></div>
        <div class="shop">
          <div class="shop-label">Sales Receipt</div>
        </div>
        <div class="rule"></div>
        ''';
    final customerName = customer?.name.trim().isNotEmpty == true
        ? customer!.name
        : _guestCustomerName;
    final customerPhone = customer?.phone.trim().isNotEmpty == true
        ? customer!.phone
        : '-';
    final customerAddress = customer?.address.trim().isNotEmpty == true
        ? customer!.address
        : '-';

    final rows = bill.items.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final item = entry.value;
      return '''
        <tr>
          <td class="center">$idx</td>
          <td>${_escapeHtml(item.productName)}${item.taxDescription.isEmpty ? '' : '<br><small>${_escapeHtml(item.taxDescription)}</small>'}</td>
          <td class="num">${item.quantity}</td>
          <td class="num">${_escapeHtml(AppUtils.formatCurrency(item.price))}</td>
          <td class="num">${_escapeHtml(AppUtils.formatCurrency(item.subtotal))}</td>
        </tr>
      ''';
    }).join();

    return '''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Receipt ${_escapeHtml(bill.id)}</title>
    <style>
      body { font-family: Arial, sans-serif; padding: 20px; color: #111; }
      .rule { border-top: 1.4px solid #222; margin: 6px 0; }
      .shop { text-align: center; margin: 8px 0; }
      .shop-label { font-size: 11px; letter-spacing: 1.3px; text-transform: uppercase; color: #444; }
      .shop h2 { margin: 4px 0 2px; font-size: 22px; }
      .shop-sub { font-size: 12px; color: #333; line-height: 1.3; }
      .meta-grid {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 10px;
        margin: 12px 0;
      }
      .meta-box {
        border: 1px solid #d8d8d8;
        border-radius: 6px;
        padding: 8px 10px;
        line-height: 1.45;
        font-size: 12px;
      }
      .meta-title { font-size: 11px; font-weight: 700; text-transform: uppercase; color: #555; margin-bottom: 4px; }
      table { width: 100%; border-collapse: collapse; margin-top: 8px; }
      th, td { border: 1px solid #ddd; padding: 7px 6px; font-size: 12px; }
      th { text-align: left; background: #f4f4f4; }
      .num { text-align: right; }
      .center { text-align: center; }
      .totals { margin-top: 12px; margin-left: auto; width: 320px; }
      .totals div { display: flex; justify-content: space-between; margin: 3px 0; font-size: 13px; }
      .grand { font-weight: 700; font-size: 16px; border-top: 1px dashed #444; padding-top: 8px; margin-top: 8px; }
      .note { margin-top: 14px; text-align: center; font-size: 12px; color: #555; }
      @media print { body { padding: 0; } }
    </style>
  </head>
  <body>
    $shopDetailsHtml

    <div class="meta-grid">
      <div class="meta-box">
        <div class="meta-title">Bill Details</div>
        <div><strong>Bill No:</strong> ${_escapeHtml(bill.id)}</div>
        <div><strong>Date:</strong> ${_escapeHtml(_formatDateTime(bill.createdAt))}</div>
      </div>
      <div class="meta-box">
        <div class="meta-title">Customer Details</div>
        <div><strong>Name:</strong> ${_escapeHtml(customerName)}</div>
        <div><strong>Mobile:</strong> ${_escapeHtml(customerPhone)}</div>
        <div><strong>Address:</strong> ${_escapeHtml(customerAddress)}</div>
      </div>
    </div>

    <table>
      <thead>
        <tr>
          <th class="center" style="width: 42px;">No</th>
          <th>Item Name</th>
          <th class="num">Qty</th>
          <th class="num">Price</th>
          <th class="num">Amount</th>
        </tr>
      </thead>
      <tbody>
        $rows
      </tbody>
    </table>

    <div class="totals">
      <div><span>Subtotal</span><span>${_escapeHtml(AppUtils.formatCurrency(bill.subtotal))}</span></div>
      <div><span>Tax</span><span>${_escapeHtml(AppUtils.formatCurrency(bill.taxAmount))}</span></div>
      <div class="grand"><span>Total</span><span>${_escapeHtml(AppUtils.formatCurrency(bill.total))}</span></div>
    </div>

    <div class="note">Thank you for shopping with us</div>

    <script>
      window.onload = function () {
        window.print();
      };
    </script>
  </body>
</html>
''';
  }

  Future<void> _openPrintDialog(String htmlContent) async {
    try {
      await const MethodChannel('com.swiftmart/printing')
          .invokeMethod<void>('printReceipt', htmlContent);
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to print receipt: ${error.message}')),
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return AppUtils.formatDateTime(dateTime);
  }

  String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  Future<void> _showCashierProfileDialog() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      return;
    }

    final emailController = TextEditingController(text: user.email);
    final mobileController = TextEditingController(text: user.mobile);
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    Future<void> submit(BuildContext dialogContext) async {
      final email = emailController.text.trim();
      final mobile = mobileController.text.trim();
      final currentPassword = currentPasswordController.text;
      final newPassword = newPasswordController.text;
      final confirmPassword = confirmPasswordController.text;
      final wantsPasswordChange =
          currentPassword.isNotEmpty || newPassword.isNotEmpty || confirmPassword.isNotEmpty;

      if (email.isEmpty || mobile.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email and mobile number are required')),
        );
        return;
      }

      if (wantsPasswordChange) {
        if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fill all password fields to change password')),
          );
          return;
        }

        if (newPassword != confirmPassword) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New password and confirm password must match')),
          );
          return;
        }

        if (newPassword.length < 4) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password must be at least 4 characters')),
          );
          return;
        }
      }

      final profileUpdated = await auth.updateMyProfile(email: email, mobile: mobile);
      if (!profileUpdated) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.error ?? 'Failed to update profile')),
        );
        return;
      }

      if (wantsPasswordChange) {
        final passwordUpdated = await auth.changeOwnPassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
        if (!mounted) {
          return;
        }
        if (!passwordUpdated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(auth.error ?? 'Failed to update password')),
          );
          return;
        }
      }

      if (!mounted) {
        return;
      }

      Navigator.of(dialogContext).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wantsPasswordChange
                ? 'Profile and password updated successfully'
                : 'Profile updated successfully',
          ),
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile number'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Current password'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm new password'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => submit(dialogContext),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _syncSelectedCustomerFromCurrentBill(
    BillProvider billProvider,
    CustomerProvider customerProvider,
  ) {
    if (_customerFocusNode.hasFocus && _isTypingCustomerSearch && !_isProgrammaticCustomerUpdate) {
      return;
    }

    final currentBill = billProvider.currentBill;
    if (currentBill == null) {
      return;
    }

    final nextCustomerId =
        currentBill.customerId.trim().isEmpty ? _guestCustomerId : currentBill.customerId;
    final nextCustomerName = nextCustomerId == _guestCustomerId
        ? _guestCustomerName
        : customerProvider.getCustomerById(nextCustomerId)?.name ?? _guestCustomerName;

    if (_selectedCustomerId == nextCustomerId && _customerController.text == nextCustomerName) {
      return;
    }

    _isProgrammaticCustomerUpdate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedCustomerId = nextCustomerId;
        _customerController.text = nextCustomerName;
        _customerController.selection = TextSelection.collapsed(
          offset: _customerController.text.length,
        );
      });

      Future.delayed(const Duration(milliseconds: 80), () {
        if (!mounted) {
          return;
        }
        _isProgrammaticCustomerUpdate = false;
      });
    });
  }

  Future<void> _activateOrCreateBillForCustomer(String customerId) async {
    final billProvider = context.read<BillProvider>();
    Bill? existing;

    for (final bill in billProvider.openBills) {
      final normalized = bill.customerId.trim().isEmpty ? _guestCustomerId : bill.customerId;
      if (normalized == customerId) {
        existing = bill;
        break;
      }
    }

    if (existing != null) {
      await billProvider.switchToBill(existing.id);
      return;
    }

    final current = billProvider.currentBill;
    final currentHasItems = current != null && current.items.isNotEmpty;

    if (!currentHasItems && current != null) {
      await billProvider.updateCurrentBillCustomer(customerId);
      return;
    }

    await billProvider.createNewBill(customerId);
  }
}

class _ActiveBillDropdown extends StatelessWidget {
  final List<Bill> openBills;
  final String? activeBillId;
  final CustomerProvider customerProvider;
  final Future<void> Function(String billId) onSelectBill;
  final Future<void> Function(String billId) onRemoveBill;

  const _ActiveBillDropdown({
    required this.openBills,
    required this.activeBillId,
    required this.customerProvider,
    required this.onSelectBill,
    required this.onRemoveBill,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBill = openBills.firstWhere(
      (bill) => bill.id == activeBillId,
      orElse: () => openBills.isNotEmpty ? openBills.first : Bill(
        id: '',
        customerId: 'guest',
        subtotal: 0,
        taxAmount: 0,
        total: 0,
        status: BillStatus.pending,
        paymentMethod: 'cash',
        createdAt: DateTime.now(),
        items: const [],
      ),
    );

    final selectedName = openBills.isEmpty
        ? 'No active bills'
        : (selectedBill.customerId == 'guest' || selectedBill.customerId.isEmpty
            ? 'Guest Customer'
            : (customerProvider.getCustomerById(selectedBill.customerId)?.name ?? 'Customer #${selectedBill.customerId}'));

    return InkWell(
      onTap: openBills.isEmpty
          ? null
          : () {
              showDialog<void>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: const Text('Active Bills'),
                    contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    content: SizedBox(
                      width: 360,
                      height: 280,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: openBills.length,
                        itemBuilder: (context, index) {
                          final bill = openBills[index];
                          final customerName = bill.customerId == 'guest' || bill.customerId.isEmpty
                              ? 'Guest Customer'
                              : (customerProvider.getCustomerById(bill.customerId)?.name ?? 'Customer #${bill.customerId}');
                          final isActive = bill.id == activeBillId;

                          return ListTile(
                            dense: true,
                            selected: isActive,
                            title: Text(
                              customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              Navigator.pop(dialogContext);
                              onSelectBill(bill.id);
                            },
                            trailing: IconButton(
                              tooltip: 'Remove customer bill',
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                onRemoveBill(bill.id);
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                          );
                        },
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close'),
                      ),
                    ],
                  );
                },
              );
            },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Active Bill',
          prefixIcon: const Icon(Icons.receipt_long_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: openBills.isEmpty ? Colors.grey.shade600 : null,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

class _CashierInlineBadge extends StatelessWidget {
  final AuthProvider authProvider;
  final VoidCallback onProfileTap;

  const _CashierInlineBadge({
    required this.authProvider,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final user = authProvider.user;
    final username = user?.username ?? 'User';
    final email = (user?.email ?? '').trim().isEmpty ? 'Not available' : user!.email;
    final mobile = (user?.mobile ?? '').trim().isEmpty ? 'Not available' : user!.mobile;

    return Tooltip(
      waitDuration: const Duration(milliseconds: 150),
      message: 'Username: $username\nEmail: $email\nMobile: $mobile',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onProfileTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: _POSScreenState._userBadgeHeight,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBDBDBD)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: const Color(0xFFD9E9FF),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF1565C0),
                    size: 14,
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0D47A1),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 1,
                  height: 24,
                  color: const Color(0xFFB9D3FF),
                ),
                IconButton(
                  tooltip: 'Logout',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 26, height: 26),
                  onPressed: () {
                    context.read<AuthProvider>().logout();
                  },
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 16,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _TotalRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 16 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 16 : 14,
          ),
        ),
      ],
    );
  }
}
