import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  List<Product> _lowStockAlerts = [];
  List<StockLog> _stockLogs = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  List<Product> get products => _products;
  List<Product> get filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products
        .where((p) =>
            p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.sku.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<Product> get lowStockAlerts => _lowStockAlerts;
  List<StockLog> get stockLogs => _stockLogs;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await ApiService.getProducts();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchLowStockAlerts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _lowStockAlerts = await ApiService.getLowStockAlerts();
      notifyListeners();
    } catch (e) {
      _lowStockAlerts = [];
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchStockLogs({String? productId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _stockLogs = await ApiService.getStockLogs(productId: productId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateStock(String productId, int quantity) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedProduct = await ApiService.updateStock(productId, quantity);

      // Update in local list
      final index = _products.indexWhere((p) => p.id == productId);
      if (index != -1) {
        _products[index] = updatedProduct;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addProduct(
    String name,
    String sku,
    String category,
    double price,
    int reorderLevel,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newProduct = await ApiService.addProduct(name, sku, category, price, reorderLevel);
      _products.add(newProduct);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> restockProduct(
    String productId,
    int quantity, {
    String notes = '',
  }) async {    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiService.restockProduct(productId, quantity, notes: notes);
      await fetchProducts();
      await fetchLowStockAlerts();
      await fetchStockLogs();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<bool> updateReorderLevel(String productId, int reorderLevel) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiService.updateReorderLevel(productId, reorderLevel);
      await fetchProducts();
      await fetchLowStockAlerts();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Product? getProductBySku(String sku) {
    try {
      return _products.firstWhere((p) => p.sku.toLowerCase() == sku.toLowerCase());
    } catch (e) {
      return null;
    }
  }

  Product? getProductById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
