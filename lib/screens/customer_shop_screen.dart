import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/customer_catalog.dart';
import '../services/server_settings.dart';

String _money(int paise) =>
    'INR ${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';

class CustomerShopScreen extends StatefulWidget {
  const CustomerShopScreen({super.key, this.store, this.client});

  final CustomerCatalogStore? store;
  final CustomerCatalogClient? client;

  @override
  State<CustomerShopScreen> createState() => _CustomerShopScreenState();
}

class _CustomerShopScreenState extends State<CustomerShopScreen> {
  late final CustomerCatalogClient _client =
      widget.client ?? CustomerCatalogClient();
  CustomerCatalogStore? _store;
  CustomerCatalog? _catalog;
  List<CustomerCartLine> _cart = [];
  String _search = '';
  String? _notice;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final store = widget.store ?? await CustomerCatalogStore.open();
      final catalog = await store.load();
      final cart = await store.cart();
      if (!mounted) {
        if (widget.store == null) await store.close();
        return;
      }
      setState(() {
        _store = store;
        _catalog = catalog;
        _cart = cart;
        _loading = false;
      });
      if (catalog != null) await _refresh(catalog.address);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _notice = 'Could not open the saved catalog: $error';
        });
      }
    }
  }

  @override
  void dispose() {
    if (widget.client == null) _client.close();
    if (widget.store == null && _store != null) _store!.close();
    super.dispose();
  }

  Future<void> _refresh(String address) async {
    if (_busy || _store == null) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final catalog = await _client.fetch(address);
      if (!mounted) return;
      await _store!.save(catalog);
      final saved = await _store!.load();
      final cart = await _store!.cart();
      if (mounted) {
        setState(() {
          _catalog = saved;
          _cart = cart;
          _notice =
              'Catalog updated. Prices and availability can still change.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _notice =
            'Could not update the catalog: $error. Your saved catalog is unchanged.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    final controller = TextEditingController(text: _catalog?.address ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect to a shop'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ask the shop for its catalog server address. '
                'Connect to its network if needed.'),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                  labelText: 'Shop server address',
                  hintText: 'https://shop.example'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Connect')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    String address;
    try {
      address = ServerSettings.normalizeAddress(value);
    } on FormatException catch (error) {
      setState(() => _notice = error.message);
      return;
    }
    if (Uri.parse(address).scheme == 'http') {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unencrypted catalog connection'),
          content: const Text(
              'Others on the network may see or change this catalog. '
              'Use HTTPS if possible, and verify prices with the shop.'),
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
    if (_catalog != null && _catalog!.address != address && _cart.isNotEmpty) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Change shop?'),
          content: const Text(
              'Connecting to a different shop clears your current cart '
              'after the new catalog downloads successfully.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Change shop')),
          ],
        ),
      );
      if (approved != true || !mounted) return;
    }
    await _refresh(address);
  }

  Future<void> _setQuantity(CustomerProduct product, int quantity) async {
    if (_busy || _store == null) return;
    setState(() => _busy = true);
    try {
      await _store!.setQuantity(product, quantity);
      final cart = await _store!.cart();
      if (mounted) setState(() => _cart = cart);
    } catch (error) {
      if (mounted) setState(() => _notice = 'Could not update cart: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openCart() async {
    final catalog = _catalog;
    final store = _store;
    if (catalog == null || store == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CustomerCartScreen(catalog: catalog, store: store),
    ));
    if (!mounted) return;
    try {
      final cart = await store.cart();
      if (mounted) setState(() => _cart = cart);
    } catch (error) {
      if (mounted) setState(() => _notice = 'Could not load cart: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    final quantities = {
      for (final line in _cart) line.product.id: line.quantity
    };
    final products = catalog?.products
            .where((product) => '${product.name} ${product.category}'
                .toLowerCase()
                .contains(_search.toLowerCase()))
            .toList() ??
        [];
    return Scaffold(
      appBar: AppBar(
        title: Text(catalog?.shopName ?? 'Shop from home'),
        actions: [
          IconButton(
            tooltip: 'Connect to a shop',
            onPressed: _loading || _busy ? null : _connect,
            icon: const Icon(Icons.store_outlined),
          ),
          if (catalog != null)
            IconButton(
              tooltip: 'Refresh catalog',
              onPressed: _busy ? null : () => _refresh(catalog.address),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_busy) const LinearProgressIndicator(),
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_notice!),
                  ),
                if (catalog == null)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.storefront_outlined, size: 64),
                            const SizedBox(height: 12),
                            const Text(
                                'Connect at the shop once to save its catalog '
                                'on this phone. Browse and prepare an order later, even offline.',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton(
                                onPressed:
                                    _busy || _store == null ? null : _connect,
                                child: const Text('Connect to shop')),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Saved ${DateFormat.yMMMd().add_jm().format(catalog.syncedAt.toLocal())}'),
                        const Text(
                            'Prices and availability must be confirmed by the shop.'),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Search products',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) => setState(() => _search = value),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: products.isEmpty
                        ? const Center(
                            child: Text(
                                'No matching products in the saved catalog.'))
                        : ListView.builder(
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final product = products[index];
                              final quantity = quantities[product.id] ?? 0;
                              return ListTile(
                                title: Text(product.name),
                                subtitle: Text(
                                    '${product.category}  ${_money(product.pricePaise)}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Remove one',
                                      onPressed: _busy || quantity == 0
                                          ? null
                                          : () => _setQuantity(
                                              product, quantity - 1),
                                      icon: const Icon(
                                          Icons.remove_circle_outline),
                                    ),
                                    Text('$quantity'),
                                    IconButton(
                                      tooltip: 'Add one',
                                      onPressed: _busy || quantity == 99
                                          ? null
                                          : () => _setQuantity(
                                              product, quantity + 1),
                                      icon:
                                          const Icon(Icons.add_circle_outline),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ],
            ),
      bottomNavigationBar: catalog == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _busy || _cart.isEmpty ? null : _openCart,
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: Text(
                      'Review order (${_cart.fold<int>(0, (sum, line) => sum + line.quantity)} items)'),
                ),
              ),
            ),
    );
  }
}

class CustomerCartScreen extends StatefulWidget {
  const CustomerCartScreen(
      {super.key, required this.catalog, required this.store});
  final CustomerCatalog catalog;
  final CustomerCatalogStore store;

  @override
  State<CustomerCartScreen> createState() => _CustomerCartScreenState();
}

class _CustomerCartScreenState extends State<CustomerCartScreen> {
  static const _share = MethodChannel('com.swiftmart/share');
  final _name = TextEditingController();
  final _address = TextEditingController();
  List<CustomerCartLine> _lines = [];
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final lines = await widget.store.cart();
      if (mounted) setState(() => _lines = lines);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not load your order: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(CustomerCartLine line) async {
    setState(() => _busy = true);
    try {
      await widget.store.setQuantity(line.product, 0);
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Could not remove item: $error';
          _busy = false;
        });
      }
    }
  }

  Future<void> _preview() async {
    if (_name.text.trim().isEmpty || _address.text.trim().isEmpty) {
      setState(() => _error = 'Enter your name and delivery address.');
      return;
    }
    final total = _lines.fold<int>(
        0, (sum, line) => sum + line.product.pricePaise * line.quantity);
    final message = StringBuffer()
      ..writeln('Order request for ${widget.catalog.shopName}')
      ..writeln('Customer: ${_name.text.trim()}')
      ..writeln('Delivery address: ${_address.text.trim()}')
      ..writeln()
      ..writeln('Items:');
    for (final line in _lines) {
      message.writeln(
          '- ${line.product.name} × ${line.quantity} @ ${_money(line.product.pricePaise)}'
          '${line.available ? '' : ' (availability needs confirmation)'}');
    }
    message
      ..writeln()
      ..writeln(
          'Estimated items total: ${_money(total)} (tax and delivery extra if applicable).')
      ..writeln(
          'Catalog saved: ${DateFormat.yMMMd().add_jm().format(widget.catalog.syncedAt.toLocal())}.')
      ..writeln(
          'Please confirm availability, final amount and delivery, and send your payment details.');
    final text = message.toString();
    final share = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preview order request'),
        content: SingleChildScrollView(child: SelectableText(text)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Edit')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Share')),
        ],
      ),
    );
    if (share != true || !mounted) return;
    try {
      await _share.invokeMethod<void>('shareOrder', text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Choose WhatsApp and the shop contact. Your order is not confirmed until the shop replies.')));
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() =>
            _error = 'Could not open sharing: ${error.message ?? error.code}');
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() => _error = 'Sharing is not available on this device.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _lines.fold<int>(
        0, (sum, line) => sum + line.product.pricePaise * line.quantity);
    return Scaffold(
      appBar: AppBar(title: const Text('Review order')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('This is an order request, not a confirmed order. '
              'The shop must confirm items, final price and delivery.'),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          for (final line in _lines)
            ListTile(
              title: Text(line.product.name),
              subtitle: Text(
                  '${line.quantity} × ${_money(line.product.pricePaise)}'
                  '${line.available ? '' : ' — no longer in the latest catalog'}'),
              trailing: IconButton(
                tooltip: 'Remove item',
                onPressed: _busy ? null : () => _remove(line),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          if (_lines.isEmpty && !_busy) const Text('Your cart is empty.'),
          Text('Estimated items total: ${_money(total)}'),
          const Text(
              'Tax and delivery may be extra. Prices and availability may have changed.'),
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Your name')),
          TextField(
            controller: _address,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Delivery address'),
          ),
          const SizedBox(height: 12),
          const Text(
              'Your name and address are included in the message you choose to share. '
              'They are not saved by this screen. Internet access is needed to send.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy || _lines.isEmpty ? null : _preview,
            icon: const Icon(Icons.share),
            label: const Text('Preview and share order'),
          ),
          const SizedBox(height: 12),
          const Text(
              'Ask the shop for its UPI details after it confirms the order. '
              'Verify the payee before paying; this app cannot confirm payment.'),
        ],
      ),
    );
  }
}
