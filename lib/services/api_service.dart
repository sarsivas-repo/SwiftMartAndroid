import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/models.dart';
import '../models/sandbox_payment.dart';
import 'local_users.dart';
import 'local_stock.dart';
import 'local_sales.dart';
import 'app_license.dart';

class ApiService {
  static String _baseUrl = '';
  static String? _authToken;
  static LocalUsers? _localUsers;
  static bool get isLocal => _localUsers != null;

  static void configureServer(String baseUrl) {
    _localUsers?.logout();
    _localUsers = null;
    _authToken = null;
    _baseUrl = baseUrl;
  }

  static void configureLocal(LocalUsers users) {
    _authToken = null;
    _baseUrl = '';
    _localUsers = users;
  }

  static Future<Map<String, dynamic>> login(String username, String password) async {
    AppLicense.instance.requireActive();
    if (_localUsers case final local?) {
      final user = await local.login(username, password);
      return {'user': user.toJson()};
    }
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      AppLicense.instance.requireActive();
      _authToken = data['token'] as String?;
      return data;
    }

    throw Exception(data['error']?.toString() ?? 'Login failed');
  }

  static Future<void> logout() async {
    _localUsers?.logout();
    _authToken = null;
  }

  static Future<Map<String, dynamic>> getMe() async {
    if (_localUsers case final local?) {
      return {'user': (await local.currentUser()).toJson()};
    }
    final response = await http.get(
      Uri.parse('$_baseUrl/auth/me'),
      headers: _getHeaders(),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['error']?.toString() ?? 'Failed to get profile');
  }

  static Future<List<User>> getUsers() async {
    if (_localUsers case final local?) return local.listUsers();
    final response = await http.get(
      Uri.parse('$_baseUrl/auth/users'),
      headers: _getHeaders(),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      final users = (data['users'] as List<dynamic>? ?? []);
      return users
          .map((u) => User.fromJson(Map<String, dynamic>.from(u as Map)))
          .toList();
    }
    throw Exception(data['error']?.toString() ?? 'Failed to load users');
  }

  static Future<User> createUser(
    String username,
    String email,
    String password,
    List<UserRole> roles,
  ) async {
    if (roles.length != 1) {
      throw ArgumentError('Exactly one role is required');
    }
    if (_localUsers case final local?) {
      return local.createUser(username, email, password, roles.single);
    }
    final role = roles.single.name;
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/users'),
      headers: _getHeaders(),
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'role': role,
      }),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 201) {
      return User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    }
    throw Exception(data['error']?.toString() ?? 'Failed to create user');
  }

  static Future<void> changeMyPassword(String currentPassword, String newPassword) async {
    if (_localUsers case final local?) return local.changePassword(currentPassword, newPassword);
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/change-password'),
      headers: _getHeaders(),
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error']?.toString() ?? 'Failed to update password');
    }
  }

  static Future<void> adminUpdateUserPassword(String userId, String newPassword) async {
    if (_localUsers case final local?) return local.resetPassword(userId, newPassword);
    final response = await http.put(
      Uri.parse('$_baseUrl/auth/users/$userId/password'),
      headers: _getHeaders(),
      body: jsonEncode({'new_password': newPassword}),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error']?.toString() ?? 'Failed to reset user password');
    }
  }

  static Future<User> updateMyProfile({
    required String email,
    required String mobile,
  }) async {
    if (_localUsers case final local?) return local.updateProfile(email: email, mobile: mobile);
    final response = await http.put(
      Uri.parse('$_baseUrl/auth/me/profile'),
      headers: _getHeaders(),
      body: jsonEncode({'email': email, 'mobile': mobile}),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      return User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    }
    throw Exception(data['error']?.toString() ?? 'Failed to update profile');
  }

  static Future<User> updateUser(
    String userId, {
    required String username,
    required String email,
    required String mobile,
    required List<UserRole> roles,
    required bool isActive,
  }) async {
    if (roles.length != 1) {
      throw ArgumentError('Exactly one role is required');
    }
    if (_localUsers case final local?) {
      return local.updateUser(userId, username: username, email: email,
          mobile: mobile, role: roles.single, active: isActive);
    }
    final role = roles.single.name;
    final response = await http.put(
      Uri.parse('$_baseUrl/auth/users/$userId'),
      headers: _getHeaders(),
      body: jsonEncode({
        'username': username,
        'email': email,
        'mobile': mobile,
        'role': role,
        'is_active': isActive,
      }),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      return User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    }
    throw Exception(data['error']?.toString() ?? 'Failed to update user');
  }

  static Future<void> deleteUser(String userId, {bool hardDelete = false}) async {
    if (_localUsers case final local?) return local.deleteUser(userId);
    final response = await http.delete(
      Uri.parse('$_baseUrl/auth/users/$userId'),
      headers: _getHeaders(),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error']?.toString() ?? 'Failed to delete user');
    }
  }

  static Future<bool> shouldShowDefaultAdminHint() async {
    if (_localUsers != null) return false;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/setup-status'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = _decodeBody(response.body);
        return data['status'] == 'needs_setup';
      }
    } catch (_) {}
    return false;
  }

  static Future<List<Product>> getProducts() async {
    if (_localUsers case final local?) return LocalStock(local).products();
    final response = await http.get(
      Uri.parse('$_baseUrl/stock/products'),
      headers: _getHeaders(),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      final items = (data['products'] as List<dynamic>? ?? []);
      return items
          .map((p) => Product.fromJson(_mapBackendProduct(Map<String, dynamic>.from(p as Map))))
          .toList();
    }
    throw Exception(data['error']?.toString() ?? 'Failed to load products');
  }

  static Future<Product> addProduct(
    String name,
    String sku,
    String category,
    double price,
    int reorderLevel,
  ) async {
    if (_localUsers case final local?) {
      return LocalStock(local).add(name, sku, category, price, reorderLevel);
    }
    final response = await http.post(
      Uri.parse('$_baseUrl/stock/add'),
      headers: _getHeaders(),
      body: jsonEncode({
        'name': name,
        'category': category,
        'barcode': sku,
        'price': price,
        'quantity': 0,
        'low_stock_threshold': reorderLevel,
      }),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 201) {
      return Product.fromJson(_mapBackendProduct(Map<String, dynamic>.from(data['product'] as Map)));
    }
    throw Exception(data['error']?.toString() ?? 'Failed to add product');
  }

  static Future<Product> updateStock(String productId, int quantity) async {
    if (_localUsers case final local?) return LocalStock(local).adjust(productId, quantity);
    final response = await http.put(
      Uri.parse('$_baseUrl/stock/update/$productId'),
      headers: _getHeaders(),
      body: jsonEncode({'quantity': quantity, 'change_type': 'ADJUSTMENT'}),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error']?.toString() ?? 'Failed to update stock');
    }

    final products = await getProducts();
    return products.firstWhere((p) => p.id == productId);
  }

  static Future<void> updateReorderLevel(String productId, int reorderLevel) async {
    if (_localUsers case final local?) return LocalStock(local).reorder(productId, reorderLevel);
    final response = await http.put(
      Uri.parse('$_baseUrl/stock/reorder/$productId'),
      headers: _getHeaders(),
      body: jsonEncode({'low_stock_threshold': reorderLevel}),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error']?.toString() ?? 'Failed to update minimum stock level');
    }
  }

  static Future<void> updateProductPricing(String productId, String taxMode,
      int taxBasisPoints, int? mrpMinor) async {
    if (_localUsers case final local?) {
      return LocalStock(local).updatePricing(productId, taxMode, taxBasisPoints, mrpMinor);
    }
    final response = await http.put(
      Uri.parse('$_baseUrl/stock/pricing/$productId'),
      headers: _getHeaders(),
      body: jsonEncode({'tax_mode': taxMode, 'tax_basis_points': taxBasisPoints,
          'mrp_minor': mrpMinor}),
    );
    if (response.statusCode != 200) {
      final data = _decodeBody(response.body);
      throw Exception(data['error']?.toString() ?? 'Failed to update sales tax');
    }
  }

  static Future<Map<String, dynamic>> recordPurchase({
    required String productId,
    required String requestId,
    required int quantity,
    required int unitCostMinor,
    required String taxMode,
    required int taxBasisPoints,
    required String supplier,
    required String invoiceReference,
  }) async {
    if (_localUsers case final local?) {
      return LocalStock(local).purchase(productId, requestId, quantity,
          unitCostMinor, taxMode, taxBasisPoints, supplier, invoiceReference);
    }
    final response = await http.post(
      Uri.parse('$_baseUrl/stock/purchase/$productId'),
      headers: _getHeaders(),
      body: jsonEncode({'request_id': requestId, 'quantity': quantity,
        'unit_cost_minor': unitCostMinor, 'tax_mode': taxMode,
        'tax_basis_points': taxBasisPoints, 'supplier': supplier,
        'invoice_reference': invoiceReference}),
    );
    final data = _decodeBody(response.body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['error']?.toString() ?? 'Failed to record purchase');
    }
    return data;
  }

  static Future<void> restockProduct(
    String productId,
    int quantity, {
    String notes = '',
  }) async {
    if (_localUsers case final local?) {
      await LocalStock(local).adjust(productId, quantity, restock: true, notes: notes);
      return;
    }
    final response = await http.post(
      Uri.parse('$_baseUrl/stock/restock/$productId'),
      headers: _getHeaders(),
      body: jsonEncode({
        'quantity': quantity,
        'notes': notes,
      }),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error']?.toString() ?? 'Failed to restock product');
    }
  }

  static Future<List<Product>> getLowStockAlerts() async {
    if (_localUsers case final local?) return LocalStock(local).products(lowStock: true);
    final response = await http.get(
      Uri.parse('$_baseUrl/stock/alerts'),
      headers: _getHeaders(),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      final alerts = (data['alerts'] as List<dynamic>? ?? []);
      return alerts
          .map((a) => Map<String, dynamic>.from(a as Map))
          .map((a) => Product.fromJson(_mapBackendProduct(Map<String, dynamic>.from(a['product'] as Map))))
          .toList();
    }
    throw Exception(data['error']?.toString() ?? 'Failed to load low stock alerts');
  }

  static Future<List<StockLog>> getStockLogs({String? productId}) async {
    if (_localUsers case final local?) return LocalStock(local).logs(productId: productId);
    final response = await http.get(
      Uri.parse('$_baseUrl/stock/logs'),
      headers: _getHeaders(),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      final logs = (data['logs'] as List<dynamic>? ?? []);
      return logs
          .map((l) => StockLog.fromJson(_mapBackendStockLog(Map<String, dynamic>.from(l as Map))))
          .toList();
    }
    throw Exception(data['error']?.toString() ?? 'Failed to load stock logs');
  }

  static Future<Bill> createBill(String customerId) async {
    return Bill(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      customerId: customerId,
      subtotal: 0,
      taxAmount: 0,
      total: 0,
      status: BillStatus.pending,
      paymentMethod: 'cash',
      createdAt: DateTime.now(),
      items: const [],
    );
  }

  static Future<List<Bill>> getDraftBills() async {
    if (_localUsers case final local?) return LocalSales(local).drafts();
    final response = await http.get(
      Uri.parse('$_baseUrl/billing/drafts'),
      headers: _getHeaders(),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      final drafts = (data['drafts'] as List<dynamic>? ?? []);
      return drafts
          .map((d) => Bill.fromJson(_mapBackendDraftBill(Map<String, dynamic>.from(d as Map))))
          .toList();
    }

    throw Exception(data['error']?.toString() ?? 'Failed to load draft bills');
  }

  static Future<Bill> createDraftBill(int? customerId) async {
    if (_localUsers case final local?) return LocalSales(local).createDraft(customerId);
    final response = await http.post(
      Uri.parse('$_baseUrl/billing/drafts'),
      headers: _getHeaders(),
      body: jsonEncode({'customer_id': customerId, 'pricing_version': 1}),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 201) {
      if ((data['draft'] as Map)['pricing_version'] != 1) {
        throw StateError('The server does not support sales-tax pricing. Update the server before creating a bill.');
      }
      return Bill.fromJson(
        _mapBackendDraftBill(Map<String, dynamic>.from(data['draft'] as Map)),
      );
    }

    throw Exception(data['error']?.toString() ?? 'Failed to create draft bill');
  }

  static Future<Bill> updateDraftBillCustomer(String draftId, int? customerId) async {
    if (_localUsers case final local?) return LocalSales(local).setCustomer(draftId, customerId);
    final response = await http.put(
      Uri.parse('$_baseUrl/billing/drafts/$draftId/customer'),
      headers: _getHeaders(),
      body: jsonEncode({'customer_id': customerId}),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      return Bill.fromJson(
        _mapBackendDraftBill(Map<String, dynamic>.from(data['draft'] as Map)),
      );
    }

    throw Exception(data['error']?.toString() ?? 'Failed to update draft customer');
  }

  static Future<Bill> addItemToDraftBill(
    String draftId,
    String productId,
    int quantity,
  ) async {
    if (_localUsers case final local?) return LocalSales(local).setItem(draftId, productId, quantity, add: true);
    final response = await http.post(
      Uri.parse('$_baseUrl/billing/drafts/$draftId/items'),
      headers: _getHeaders(),
      body: jsonEncode({
        'product_id': int.tryParse(productId) ?? 0,
        'quantity': quantity,
      }),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      return Bill.fromJson(
        _mapBackendDraftBill(Map<String, dynamic>.from(data['draft'] as Map)),
      );
    }

    throw Exception(data['error']?.toString() ?? 'Failed to add item to draft bill');
  }

  static Future<Bill> addDirectItemToDraftBill(
      String draftId, String name, int quantity, int pricePaise,
      {String taxMode = 'none', int taxBasisPoints = 0}) async {
    if (_localUsers case final local?) {
      return LocalSales(local).addDirectItem(draftId, name, quantity, pricePaise,
          taxMode: taxMode, taxBasisPoints: taxBasisPoints);
    }
    final response = await http.post(
      Uri.parse('$_baseUrl/billing/drafts/$draftId/direct-items'),
      headers: _getHeaders(),
      body: jsonEncode({'name': name, 'quantity': quantity, 'price_paise': pricePaise,
          'tax_mode': taxMode, 'tax_basis_points': taxBasisPoints}),
    );
    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      return Bill.fromJson(
        _mapBackendDraftBill(Map<String, dynamic>.from(data['draft'] as Map)),
      );
    }
    throw Exception(data['error']?.toString() ?? 'Failed to add direct-sale item');
  }

  static Future<Bill> removeItemFromDraftBill(
    String draftId,
    String productId,
  ) async {
    if (_localUsers case final local?) {
      return productId.startsWith('direct:')
          ? LocalSales(local).changeDirectItem(draftId, productId)
          : LocalSales(local).removeItem(draftId, productId);
    }
    final response = await http.delete(
      Uri.parse(productId.startsWith('direct:')
          ? '$_baseUrl/billing/drafts/$draftId/direct-items/${productId.substring(7)}'
          : '$_baseUrl/billing/drafts/$draftId/items/$productId'),
      headers: _getHeaders(),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      return Bill.fromJson(
        _mapBackendDraftBill(Map<String, dynamic>.from(data['draft'] as Map)),
      );
    }

    throw Exception(data['error']?.toString() ?? 'Failed to remove item from draft bill');
  }

  static Future<Bill> updateDraftItemQuantity(
    String draftId,
    String productId,
    int quantity,
  ) async {
    if (_localUsers case final local?) {
      return productId.startsWith('direct:')
          ? LocalSales(local).changeDirectItem(draftId, productId, quantity: quantity)
          : LocalSales(local).setItem(draftId, productId, quantity);
    }
    final response = await http.put(
      Uri.parse(productId.startsWith('direct:')
          ? '$_baseUrl/billing/drafts/$draftId/direct-items/${productId.substring(7)}'
          : '$_baseUrl/billing/drafts/$draftId/items/$productId'),
      headers: _getHeaders(),
      body: jsonEncode({'quantity': quantity}),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      return Bill.fromJson(
        _mapBackendDraftBill(Map<String, dynamic>.from(data['draft'] as Map)),
      );
    }

    throw Exception(data['error']?.toString() ?? 'Failed to update item quantity');
  }

  static Future<void> deleteDraftBill(String draftId) async {
    if (_localUsers case final local?) return LocalSales(local).deleteDraft(draftId);
    final response = await http.delete(
      Uri.parse('$_baseUrl/billing/drafts/$draftId'),
      headers: _getHeaders(),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error']?.toString() ?? 'Failed to remove draft bill');
    }
  }

  static Future<Map<String, dynamic>> checkoutDraftBill(
    String draftId,
    double taxAmount,
    String paymentMethod,
  ) async {
    if (_localUsers case final local?) return LocalSales(local).checkout(draftId, taxAmount, paymentMethod);
    final response = await http.post(
      Uri.parse('$_baseUrl/billing/drafts/$draftId/checkout'),
      headers: _getHeaders(),
      body: jsonEncode({
        'tax': taxAmount,
        'payment_method': paymentMethod,
      }),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(data['error']?.toString() ?? 'Draft checkout failed');
  }

  static Future<Map<String, dynamic>> getPaymentProviderConfig() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/billing/payments/providers'),
      headers: _getHeaders(),
    );
    final data = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw SandboxPaymentException(
        data['error']?.toString() ?? 'Payments are unavailable on this server',
        statusCode: response.statusCode,
      );
    }
    if (!const {'sandbox', 'live'}.contains(data['mode']) ||
        data['providers'] is! List ||
        data['selected_provider'] is! String) {
      throw const FormatException('Invalid payment provider response');
    }
    final providers = <String>[];
    for (final value in data['providers'] as List) {
      if (value is! Map ||
          value['name'] is! String ||
          value['configured'] is! bool) {
        throw const FormatException('Invalid payment provider response');
      }
      if (value['configured'] == true) providers.add(value['name'] as String);
    }
    return {
      'mode': data['mode'],
      'providers': providers,
      'selected_provider': data['selected_provider'],
    };
  }

  static Future<void> setPaymentProvider(String provider) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/billing/payments/settings'),
      headers: _getHeaders(),
      body: jsonEncode({'provider': provider}),
    );
    if (response.statusCode != 200) {
      final data = _decodeBody(response.body);
      throw Exception(data['error']?.toString() ?? 'Failed to save payment settings');
    }
  }

  static Future<SandboxPayment?> getSandboxPaymentForDraft(String draftId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/billing/drafts/${Uri.encodeComponent(draftId)}/payment'),
      headers: _getHeaders(),
    );
    final data = _decodeBody(response.body);
    if (response.statusCode == 404 && data['error'] == 'Payment attempt not found') {
      return null;
    }
    return _sandboxPaymentResponse(response, data);
  }

  static Future<List<SandboxPayment>> getSandboxPayments() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/billing/payments'),
      headers: _getHeaders(),
    );
    final data = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw SandboxPaymentException(
        data['error']?.toString() ?? 'Failed to load payments',
        statusCode: response.statusCode,
      );
    }
    if (data['payments'] is! List) {
      throw const FormatException('Invalid payment list response');
    }
    return (data['payments'] as List).map((value) {
      if (value is! Map) {
        throw const FormatException('Invalid payment list response');
      }
      return SandboxPayment.fromJson(Map<String, dynamic>.from(value));
    }).toList();
  }

  static Future<SandboxPayment> createSandboxPayment({
    required String draftId,
    required String provider,
    required int taxPaise,
    required String customerPhone,
    required String os,
    required String browser,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/billing/drafts/${Uri.encodeComponent(draftId)}/payment'),
      headers: _getHeaders(),
      body: jsonEncode({
        'provider': provider,
        'tax_paise': taxPaise,
        'customer_phone': customerPhone,
        'device': 'mobile',
        'os': 'android',
        'browser': 'others',
        'rendering_type': 'native',
      }),
    );
    return _sandboxPaymentResponse(response, _decodeBody(response.body));
  }

  static Future<SandboxPayment> checkSandboxPayment(String id) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/billing/payments/${Uri.encodeComponent(id)}/check'),
      headers: _getHeaders(),
    );
    return _sandboxPaymentResponse(response, _decodeBody(response.body));
  }

  static Future<SandboxPayment> recoverSandboxRazorpayPayment(
      String id, String reference) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/billing/payments/${Uri.encodeComponent(id)}/recover-razorpay'),
      headers: _getHeaders(),
      body: jsonEncode({'provider_reference': reference}),
    );
    return _sandboxPaymentResponse(response, _decodeBody(response.body));
  }

  static SandboxPayment _sandboxPaymentResponse(
      http.Response response, Map<String, dynamic> data) {
    final value = data['payment'];
    final payment = value is Map
        ? SandboxPayment.fromJson(Map<String, dynamic>.from(value))
        : null;
    if (response.statusCode != 200) {
      throw SandboxPaymentException(
        data['error']?.toString() ?? 'Payment request failed',
        statusCode: response.statusCode,
        payment: payment,
      );
    }
    if (payment == null) {
      throw const FormatException('Payment response is missing');
    }
    return payment;
  }

  static Future<BillItem> addItemToBill(
    String billId,
    String productId,
    int quantity,
  ) async {
    final products = await getProducts();
    final product = products.firstWhere((p) => p.id == productId);

    final validateResponse = await http.post(
      Uri.parse('$_baseUrl/billing/add-item'),
      headers: _getHeaders(),
      body: jsonEncode({
        'product_id': int.tryParse(productId) ?? 0,
        'quantity': quantity,
        'price': product.price,
      }),
    );

    final data = _decodeBody(validateResponse.body);
    if (validateResponse.statusCode != 200) {
      throw Exception(data['error']?.toString() ?? 'Failed to add item to bill');
    }

    return BillItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      billId: billId,
      productId: product.id,
      productName: product.name,
      price: product.price,
      quantity: quantity,
      subtotal: product.price * quantity,
    );
  }

  static Future<void> removeItemFromBill(String billId, String itemId) async {
    return;
  }

  static Future<Bill> checkout(
    Bill bill,
    double taxAmount,
    String paymentMethod,
  ) async {
    final customerID = int.tryParse(bill.customerId);
    final subtotal = bill.items.fold<double>(0, (sum, item) => sum + item.subtotal);

    final response = await http.post(
      Uri.parse('$_baseUrl/billing/checkout'),
      headers: _getHeaders(),
      body: jsonEncode({
        'customer_id': customerID,
        'subtotal': subtotal,
        'tax': taxAmount,
        'items': bill.items
            .map((item) => {
                  'product_id': int.tryParse(item.productId) ?? 0,
                  'quantity': item.quantity,
                  'price': item.price,
                })
            .toList(),
      }),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      return Bill(
        id: data['bill_id']?.toString() ?? bill.id,
        customerId: bill.customerId,
        subtotal: subtotal,
        taxAmount: taxAmount,
        total: _asDouble(data['total']),
        status: BillStatus.completed,
        paymentMethod: paymentMethod,
        createdAt: bill.createdAt,
        items: bill.items,
      );
    }

    throw Exception(data['error']?.toString() ?? 'Checkout failed');
  }

  static Future<String> getReceipt(String billId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/billing/receipt/$billId'),
      headers: _getHeaders(),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      return jsonEncode(data);
    }
    throw Exception(data['error']?.toString() ?? 'Failed to get receipt');
  }

  static Future<void> sendBillSms({
    required String to,
    required String message,
    required String billId,
    required String customerName,
    required double total,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/notifications/sms'),
      headers: _getHeaders(),
      body: jsonEncode({
        'to': to,
        'message': message,
        'bill_id': billId,
        'customer_name': customerName,
        'total': total,
      }),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error']?.toString() ?? 'Failed to send SMS');
    }
  }

  static Future<void> sendBillEmail({
    required String to,
    required String subject,
    required String message,
    required String billId,
    required String customerName,
    required double total,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/notifications/email'),
      headers: _getHeaders(),
      body: jsonEncode({
        'to': to,
        'subject': subject,
        'message': message,
        'bill_id': billId,
        'customer_name': customerName,
        'total': total,
      }),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error']?.toString() ?? 'Failed to send email');
    }
  }

  static Future<List<Bill>> getBills({DateTime? startDate, DateTime? endDate}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/reports/bills'),
      headers: _getHeaders(),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      final bills = (data['bills'] as List<dynamic>? ?? []);
      return bills
          .map((b) => Bill.fromJson(_mapBackendBill(Map<String, dynamic>.from(b as Map))))
          .toList();
    }
    throw Exception(data['error']?.toString() ?? 'Failed to load bills');
  }

  static Future<List<Customer>> getCustomers() async {
    if (_localUsers case final local?) return LocalSales(local).customers();
    final response = await http.get(
      Uri.parse('$_baseUrl/customer/list'),
      headers: _getHeaders(),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      final customers = (data['customers'] as List<dynamic>? ?? []);
      return customers
          .map((c) => Customer.fromJson(_mapBackendCustomer(Map<String, dynamic>.from(c as Map))))
          .toList();
    }
    throw Exception(data['error']?.toString() ?? 'Failed to load customers');
  }

  static Future<Customer> registerCustomer(
    String name,
    String email,
    String phone,
    String address,
  ) async {
    if (_localUsers case final local?) return LocalSales(local).registerCustomer(name, email, phone, address);
    final response = await http.post(
      Uri.parse('$_baseUrl/customer/register'),
      headers: _getHeaders(),
      body: jsonEncode({
        'name': name,
        'email': email,
        'phone': phone,
      }),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 201) {
      return Customer.fromJson(
        _mapBackendCustomer(Map<String, dynamic>.from(data['customer'] as Map))
          ..['address'] = address,
      );
    }
    throw Exception(data['error']?.toString() ?? 'Failed to register customer');
  }

  static Future<Customer> updateCustomer(
    String customerId,
    String name,
    String email,
    String phone,
  ) async {
    if (_localUsers case final local?) return LocalSales(local).updateCustomer(customerId, name, email, phone);
    final response = await http.put(
      Uri.parse('$_baseUrl/customer/update/$customerId'),
      headers: _getHeaders(),
      body: jsonEncode({
        'name': name,
        'email': email,
        'phone': phone,
      }),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      return Customer.fromJson(
        _mapBackendCustomer(Map<String, dynamic>.from(data['customer'] as Map)),
      );
    }

    throw Exception(data['error']?.toString() ?? 'Failed to update customer');
  }

  static Future<List<Bill>> getCustomerHistory(String customerId) async {
    if (_localUsers case final local?) return LocalSales(local).customerHistory(customerId);
    final response = await http.get(
      Uri.parse('$_baseUrl/customer/history/$customerId'),
      headers: _getHeaders(),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      final history = (data['history'] as List<dynamic>? ?? []);
      return history
          .map((bill) => Bill.fromJson(_mapBackendBill(Map<String, dynamic>.from(bill as Map))))
          .toList();
    }
    throw Exception(data['error']?.toString() ?? 'Failed to load customer history');
  }

  static Future<SalesReport> getDailySalesReport(DateTime date) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/reports/sales/daily?date=${date.toIso8601String().split('T')[0]}'),
      headers: _getHeaders(),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      return SalesReport(
        date: DateTime.tryParse(data['date']?.toString() ?? '') ?? date,
        totalSales: _asDouble(data['total_sales']),
        billCount: _asInt(data['total_bills']),
        averageBillAmount: _asInt(data['total_bills']) > 0
            ? _asDouble(data['total_sales']) / _asInt(data['total_bills'])
            : 0,
        taxCollected: 0,
      );
    }
    throw Exception(data['error']?.toString() ?? 'Failed to load daily sales report');
  }

  static Future<List<SalesReport>> getMonthlySalesReport(int year, int month) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/reports/sales/monthly?year=$year&month=$month'),
      headers: _getHeaders(),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      final breakdown = (data['daily_breakdown'] as List<dynamic>? ?? []);
      return breakdown
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .map(
            (entry) => SalesReport(
              date: DateTime.tryParse(entry['day']?.toString() ?? '') ?? DateTime(year, month, 1),
              totalSales: _asDouble(entry['sales']),
              billCount: _asInt(entry['bill_count']),
              averageBillAmount: _asInt(entry['bill_count']) > 0
                  ? _asDouble(entry['sales']) / _asInt(entry['bill_count'])
                  : 0,
              taxCollected: 0,
            ),
          )
          .toList();
    }
    throw Exception(data['error']?.toString() ?? 'Failed to load monthly sales report');
  }

  static Future<Map<String, dynamic>> getProfitLossReport(
    int year,
    int month,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/reports/financial/profit-loss?year=$year&month=$month',
      ),
      headers: _getHeaders(),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['error']?.toString() ?? 'Failed to load profit/loss report');
  }

  static Future<Map<String, dynamic>> getInvestmentReturnReport(
    int year,
    int month,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/reports/financial/investment-return?year=$year&month=$month',
      ),
      headers: _getHeaders(),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['error']?.toString() ?? 'Failed to load investment/return report');
  }

  static Future<Map<String, dynamic>> getManualFinanceEntry(int year, int month) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/reports/financial/manual-entry?year=$year&month=$month'),
      headers: _getHeaders(),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['error']?.toString() ?? 'Failed to load manual finance entry');
  }

  static Future<Map<String, dynamic>> saveManualFinanceEntry({
    required int year,
    required int month,
    required double manualInvestment,
    required double manualProfitAdjustment,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/reports/financial/manual-entry'),
      headers: _getHeaders(),
      body: jsonEncode({
        'year': year,
        'month': month,
        'manual_investment': manualInvestment,
        'manual_profit_adjustment': manualProfitAdjustment,
      }),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['error']?.toString() ?? 'Failed to save manual finance entry');
  }

  static Future<Map<String, dynamic>> getNotificationAvailability() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/notifications/availability'),
      headers: _getHeaders(),
    );
    final data = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error']?.toString() ?? 'Failed to load notification availability');
    }
    return data;
  }

  static Future<Map<String, dynamic>> getNotificationProviderConfig() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/notifications/provider-config'),
      headers: _getHeaders(),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(data['error']?.toString() ?? 'Failed to load provider config');
  }

  static Future<void> updateNotificationProviderConfig({
    required bool smsEnabled,
    required bool emailEnabled,
    required bool autoProductCodeEnabled,
    required String twilioAccountSid,
    required String twilioAuthToken,
    required String twilioFromNumber,
    required String smsDefaultCountryCode,
    required String smtpHost,
    required String smtpPort,
    required String smtpUsername,
    required String smtpPassword,
    required String smtpFrom,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/notifications/provider-config'),
      headers: _getHeaders(),
      body: jsonEncode({
        'sms_enabled': smsEnabled,
        'email_enabled': emailEnabled,
        'auto_product_code_enabled': autoProductCodeEnabled,
        'twilio_account_sid': twilioAccountSid,
        'twilio_auth_token': twilioAuthToken,
        'twilio_from_number': twilioFromNumber,
        'sms_default_country_code': smsDefaultCountryCode,
        'smtp_host': smtpHost,
        'smtp_port': smtpPort,
        'smtp_username': smtpUsername,
        'smtp_password': smtpPassword,
        'smtp_from': smtpFrom,
      }),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error']?.toString() ?? 'Failed to save provider config');
    }
  }

  static Future<List<MonthlySalary>> getMonthlySalaries({
    required int year,
    required int month,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/salary/monthly?year=$year&month=$month'),
      headers: _getHeaders(),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      final salaries = (data['salaries'] as List<dynamic>? ?? []);
      return salaries
          .map((item) => MonthlySalary.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    throw Exception(data['error']?.toString() ?? 'Failed to load monthly salaries');
  }

  static Future<MonthlySalary> saveMonthlySalary({
    required String userId,
    required int year,
    required int month,
    required double basicSalary,
    required double transportAllowance,
    required double bonus,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/salary/monthly'),
      headers: _getHeaders(),
      body: jsonEncode({
        'user_id': int.tryParse(userId) ?? 0,
        'salary_year': year,
        'salary_month': month,
        'basic_salary': basicSalary,
        'transport_allowance': transportAllowance,
        'bonus': bonus,
      }),
    );

    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      return MonthlySalary.fromJson(
        Map<String, dynamic>.from(data['salary'] as Map),
      );
    }

    throw Exception(data['error']?.toString() ?? 'Failed to save monthly salary');
  }

  static Map<String, String> _getHeaders() {
    AppLicense.instance.requireActive();
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  static void setAuthToken(String token) {
    _authToken = token;
  }

  static String? getAuthToken() {
    return _authToken;
  }

  static Map<String, dynamic> _decodeBody(String body) {
    if (body.isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return <String, dynamic>{'data': decoded};
    } catch (_) {
      // Some endpoints/proxies can return plain text for success/error.
      return <String, dynamic>{'message': body};
    }
  }

  static Map<String, dynamic> _mapBackendProduct(Map<String, dynamic> json) {
    final reorderLevel = _asInt(
      json['low_stock_threshold'] ??
          json['reorder_level'] ??
          json['reorderLevel'] ??
          json['minimum_stock_level'] ??
          json['min_qty'] ??
          json['minQty'],
    );

    return {
      'id': json['id']?.toString() ?? '',
      'name': json['name'] ?? '',
      'sku': (json['barcode'] ?? json['sku'] ?? '').toString(),
      'category': json['category'] ?? '',
      'price': _asDouble(json['price']),
      'quantity': _asInt(json['quantity']),
      'reorder_level': reorderLevel,
      'tax_mode': json['tax_mode'] ?? 'none',
      'tax_basis_points': _asInt(json['tax_basis_points']),
      'mrp_minor': json['mrp_minor'] == null ? null : _asInt(json['mrp_minor']),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> _mapBackendCustomer(Map<String, dynamic> json) {
    return {
      'id': json['id']?.toString() ?? '',
      'name': json['name'] ?? '',
      'email': json['email'] ?? '',
      'phone': json['phone'] ?? '',
      'address': json['address'] ?? '',
      'created_at': DateTime.now().toIso8601String(),
      'total_spent': _asDouble(json['total_spent']),
      'bill_count': _asInt(json['bill_count']),
    };
  }

  static Map<String, dynamic> _mapBackendBill(Map<String, dynamic> json) {
    return {
      'id': json['id']?.toString() ?? '',
      'customer_id': json['customer_id']?.toString() ?? '',
      'subtotal': _asDouble(json['subtotal']),
      'tax_amount': _asDouble(json['tax']),
      'total': _asDouble(json['total']),
      'status': 'completed',
      'payment_method': 'cash',
      'created_at': json['date']?.toString() ?? DateTime.now().toIso8601String(),
      'items': const [],
    };
  }

  static Map<String, dynamic> _mapBackendStockLog(Map<String, dynamic> json) {
    final rawType = (json['change_type'] ?? 'manual').toString().toLowerCase();
    final mappedType = (rawType == 'restock' || rawType == 'inbound') ? 'add' : rawType;

    return {
      'id': json['id']?.toString() ?? '',
      'product_id': json['product_id']?.toString() ?? '',
      'product_name': json['product_name']?.toString() ?? 'Product #${json['product_id']}',
      'username': json['username']?.toString() ?? 'System',
      'role': json['role']?.toString() ?? 'UNKNOWN',
      'type': mappedType,
      'quantity': _asInt(json['quantity_change']),
      'notes': json['notes']?.toString() ?? '',
      'created_at': json['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> _mapBackendDraftBill(Map<String, dynamic> json) {
    final customerId = json['customer_id'];
    final items = (json['items'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .map(
          (item) => {
            'id': item['direct_item_id'] != null
                ? 'direct:${item['direct_item_id']}'
                : item['product_id']?.toString() ?? '',
            'bill_id': json['id']?.toString() ?? '',
            'product_id': item['direct_item_id'] != null
                ? 'direct:${item['direct_item_id']}'
                : item['product_id']?.toString() ?? '',
            'product_name': item['product_name']?.toString() ?? '',
            'price': _asDouble(item['price']),
            'quantity': _asInt(item['quantity']),
            'subtotal': json['pricing_version'] == 1
                ? _asInt(item['line_total_minor']) / 100
                : _asDouble(item['subtotal']),
            'tax_mode': item['tax_mode'] ?? 'none',
            'tax_basis_points': _asInt(item['tax_basis_points']),
            'tax_minor': _asInt(item['tax_minor']),
          },
        )
        .toList();

    final subtotal = _asDouble(json['subtotal']);
    return {
      'id': json['id']?.toString() ?? '',
      'customer_id': customerId?.toString() ?? 'guest',
      'subtotal': subtotal,
      'tax_amount': json['pricing_version'] == 1 ? _asDouble(json['tax']) : 0,
      'total': json['pricing_version'] == 1 ? _asDouble(json['total']) : subtotal,
      'status': 'pending',
      'payment_method': 'cash',
      'created_at': json['updated_at']?.toString() ?? json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      'items': items,
      'pricing_version': _asInt(json['pricing_version']),
    };
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
