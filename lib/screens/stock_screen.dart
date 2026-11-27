import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/models.dart';
import '../widgets/product_widgets.dart';
import '../widgets/purchase_dialog.dart';
import '../widgets/sales_tax_dialog.dart';
import '../utils/app_utils.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';

class StockScreen extends StatefulWidget {
  final bool showHeaderWithUserBadge;

  const StockScreen({
    Key? key,
    this.showHeaderWithUserBadge = false,
  }) : super(key: key);

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  List<Widget> _stockTabs() {
    return const [
      Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.list, color: Color(0xFF1E88E5)),
            SizedBox(width: 6),
            Text('All Products'),
          ],
        ),
      ),
      Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, color: Color(0xFFE53935)),
            SizedBox(width: 6),
            Text('Low Stock'),
          ],
        ),
      ),
      Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, color: Color(0xFF43A047)),
            SizedBox(width: 6),
            Text('Stock Logs'),
          ],
        ),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() => _selectedTab = _tabController.index);
      _loadTabData();
    });
    _loadTabData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadTabData() async {
    final productProvider = context.read<ProductProvider>();
    if (_selectedTab == 0) {
      await productProvider.fetchProducts();
    } else if (_selectedTab == 1) {
      await productProvider.fetchLowStockAlerts();
    } else if (_selectedTab == 2) {
      await productProvider.fetchStockLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showHeaderWithUserBadge
          ? AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              toolbarHeight: 72,
              elevation: 0,
              titleSpacing: 12,
              title: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          dividerColor: Colors.transparent,
                          tabs: _stockTabs(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildUserRoleBadge(),
                  ],
                ),
              ),
            )
          : AppBar(
              toolbarHeight: 0,
              elevation: 0,
              bottom: TabBar(
                controller: _tabController,
                tabs: _stockTabs(),
              ),
            ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AllProductsTab(),
          _LowStockTab(),
          _StockLogsTab(),
        ],
      ),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton(
              onPressed: () => _showAddProductDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildUserRoleBadge() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        final username = authProvider.user?.username ?? 'User';
        final role = authProvider.user?.roleSummary ?? 'Role';
        final email = (user?.email ?? '').trim().isEmpty ? 'Not available' : user!.email;
        final mobile = (user?.mobile ?? '').trim().isEmpty ? 'Not available' : user!.mobile;

        return Tooltip(
          waitDuration: const Duration(milliseconds: 150),
          message: 'Username: $username\nEmail: $email\nMobile: $mobile',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showProfileDialog(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: Colors.blue.shade100,
                      child: Icon(
                        Icons.person,
                        size: 15,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          role,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 1,
                      height: 22,
                      color: Colors.grey.shade300,
                    ),
                    IconButton(
                      tooltip: 'Logout',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        context.read<AuthProvider>().logout();
                      },
                      icon: const Icon(Icons.logout_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showProfileDialog() async {
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

  String _generateNextProductCode(List<Product> products) {
    final matcher = RegExp(r'^P(\d+)$');
    var highestCode = 0;

    for (final product in products) {
      final match = matcher.firstMatch(product.sku.trim().toUpperCase());
      if (match == null) {
        continue;
      }
      final value = int.tryParse(match.group(1) ?? '0') ?? 0;
      if (value > highestCode) {
        highestCode = value;
      }
    }

    return 'P${(highestCode + 1).toString().padLeft(10, '0')}';
  }

  Future<void> _showAddProductDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final skuController = TextEditingController();
    final categoryController = TextEditingController();
    final priceController = TextEditingController();
    final reorderLevelController = TextEditingController(text: '10');
    final settings = context.read<AppSettingsProvider>();
    final productProvider = context.read<ProductProvider>();

    var isAutoCodeEnabled = settings.autoProductCodeEnabled;
    if (!ApiService.isLocal) {
      try {
        final providerConfig = await ApiService.getNotificationProviderConfig();
        isAutoCodeEnabled = providerConfig['auto_product_code_enabled'] == true;
      } catch (_) {
        // Fall back to locally cached setting when backend config is temporarily unavailable.
      }
    }

    final generatedSku = _generateNextProductCode(productProvider.products);

    if (isAutoCodeEnabled) {
      skuController.text = generatedSku;
    }

    if (!mounted) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
              ),
              TextField(
                controller: skuController,
                enabled: !isAutoCodeEnabled,
                decoration: InputDecoration(
                  labelText: 'Product Code',
                  helperText: isAutoCodeEnabled ? 'Auto-generated from Settings' : null,
                ),
              ),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price'),
              ),
              TextField(
                controller: reorderLevelController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Minimum Stock Level'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final price = double.tryParse(priceController.text) ?? 0.0;
              final reorderLevel = int.tryParse(reorderLevelController.text) ?? 10;
                final productCode = isAutoCodeEnabled ? generatedSku : skuController.text.trim();

              final success = await context.read<ProductProvider>().addProduct(
                    nameController.text,
                  productCode,
                    categoryController.text,
                    price,
                    reorderLevel,
                  );

              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product added successfully')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _AllProductsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, _) {
        if (productProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (productProvider.products.isEmpty) {
          return const Center(child: Text('No products found'));
        }

        return Column(
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(child: Text('Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[600]))),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[600]))),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[600]))),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Price', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[600]))),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Min Qty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[600]))),
                  const SizedBox(width: 8),
                  SizedBox(width: 40, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[600]))),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: productProvider.products.length,
                itemBuilder: (context, index) {
                  final product = productProvider.products[index];
                  return _ProductRowCard(
                    product: product,
                    onTap: () => _showProductDetailsDialog(context, product),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showProductDetailsDialog(BuildContext context, Product product) {
    final quantityController = TextEditingController();
    final parentContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(product.name),
        content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product Name: ${product.name}'),
            Text('Product Code: ${product.sku}'),
            Text('Category: ${product.category}'),
            Text('Current Quantity: ${product.quantity}'),
            Text('Price: ${AppUtils.formatCurrency(product.price)}'),
            Text('Minimum Stock Level: ${product.reorderLevel}'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  showDialog<void>(
                    context: parentContext,
                    barrierDismissible: false,
                    builder: (_) => PurchaseDialog(product: product),
                  );
                },
                icon: const Icon(Icons.receipt_long),
                label: const Text('Record purchase'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  showDialog<void>(
                    context: parentContext,
                    builder: (_) => SalesTaxDialog(product: product),
                  );
                },
                icon: const Icon(Icons.percent),
                label: const Text('Sales tax settings'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _showEditReorderLevelDialog(parentContext, product);
                },
                icon: const Icon(Icons.edit_note),
                label: const Text('Edit Minimum Stock Level'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New Quantity',
              ),
            ),
          ],
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newQuantity = int.tryParse(quantityController.text) ?? 0;
              final success = await parentContext.read<ProductProvider>().updateStock(
                    product.id,
                    newQuantity,
                  );

              if (success && dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(content: Text('Stock updated successfully')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showEditReorderLevelDialog(BuildContext context, Product product) {
    final reorderController = TextEditingController(text: product.reorderLevel.toString());
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit Minimum Stock Level'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Product: ${product.name}'),
              Text('Current Minimum: ${product.reorderLevel}'),
              const SizedBox(height: 12),
              TextField(
                controller: reorderController,
                keyboardType: TextInputType.number,
                enabled: !isSubmitting,
                decoration: const InputDecoration(
                  labelText: 'New Minimum Stock Level',
                  hintText: 'Enter new minimum quantity',
                ),
              ),
              if (isSubmitting) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final newLevel = int.tryParse(reorderController.text);
                      if (newLevel == null || newLevel < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid minimum stock level')),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      final provider = context.read<ProductProvider>();
                      final success = await provider.updateReorderLevel(product.id, newLevel);

                      if (success) {
                        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Minimum stock level updated to $newLevel')),
                          );
                        }
                      } else {
                        if (dialogContext.mounted) setDialogState(() => isSubmitting = false);
                        if (context.mounted) {
                          final error = provider.error ?? 'Failed to update minimum stock level';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.replaceFirst('Exception: ', ''))),
                          );
                        }
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LowStockTab extends StatelessWidget {
  void _showRestockDialog(BuildContext context, Product product) {
    final quantityController = TextEditingController();
    final notesController = TextEditingController(text: 'Low stock restock');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Update Stock for ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Quantity: ${product.quantity}'),
              Text('Minimum Stock Level: ${product.reorderLevel}'),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                enabled: !isSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Quantity to Add',
                  hintText: 'Enter quantity to add',
                ),
              ),
              TextField(
                controller: notesController,
                enabled: !isSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),
              if (isSubmitting) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final quantity = int.tryParse(quantityController.text) ?? 0;
                      if (quantity <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid quantity to add')),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      final provider = context.read<ProductProvider>();
                      final success = await provider.restockProduct(
                        product.id,
                        quantity,
                        notes: notesController.text.trim(),
                      );

                      if (success) {
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${product.name} stock updated successfully')),
                          );
                        }
                      } else {
                        if (dialogContext.mounted) {
                          setDialogState(() => isSubmitting = false);
                        }
                        if (context.mounted) {
                          final error = provider.error ?? 'Failed to restock product';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.replaceFirst('Exception: ', ''))),
                          );
                        }
                      }
                    },
              child: const Text('Update Stock'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, _) {
        if (productProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (productProvider.lowStockAlerts.isEmpty) {
          return const Center(child: Text('No low stock items'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: productProvider.lowStockAlerts.length,
          itemBuilder: (context, index) {
            final product = productProvider.lowStockAlerts[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.red.shade50,
              child: InkWell(
                onTap: () => _showRestockDialog(context, product),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Qty: ${product.quantity}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Min: ${product.reorderLevel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Price: ${AppUtils.formatCurrency(product.price)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StockLogsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, _) {
        if (productProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (productProvider.stockLogs.isEmpty) {
          return const Center(child: Text('No stock logs'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: productProvider.stockLogs.length,
          itemBuilder: (context, index) {
            final log = productProvider.stockLogs[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: log.type == 'add' ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        log.type == 'add' ? Icons.add : Icons.remove,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        log.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${log.username} (${log.role.toUpperCase()})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${log.type.toUpperCase()} ${log.quantity} units',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        log.createdAt.toString().split('.')[0],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}


class _ProductRowCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductRowCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: product.isLowStock ? Colors.red.shade50 : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  product.sku,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  product.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppUtils.formatCurrency(product.price),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  product.reorderLevel.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: product.isLowStock ? Colors.red : Colors.green,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      product.quantity.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
