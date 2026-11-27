import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class CustomerProvider extends ChangeNotifier {
  List<Customer> _customers = [];
  Customer? _currentCustomer;
  List<Bill> _customerHistory = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  List<Customer> get customers => _customers;
  List<Customer> get filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    return _customers
        .where((c) =>
            c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c.phone.contains(_searchQuery))
        .toList();
  }

  Customer? get currentCustomer => _currentCustomer;
  List<Bill> get customerHistory => _customerHistory;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchCustomers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _customers = await ApiService.getCustomers();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registerCustomer(
    String name,
    String email,
    String phone,
    String address,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newCustomer =
          await ApiService.registerCustomer(name, email, phone, address);
      _customers.add(newCustomer);
      _currentCustomer = newCustomer;
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

  Future<bool> updateCustomer(
    String customerId,
    String name,
    String email,
    String phone,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedCustomer = await ApiService.updateCustomer(
        customerId,
        name,
        email,
        phone,
      );

      final index = _customers.indexWhere((c) => c.id == customerId);
      if (index >= 0) {
        final existing = _customers[index];
        _customers[index] = Customer(
          id: updatedCustomer.id,
          name: updatedCustomer.name,
          email: updatedCustomer.email,
          phone: updatedCustomer.phone,
          address: existing.address,
          createdAt: existing.createdAt,
          totalSpent: existing.totalSpent,
          billCount: existing.billCount,
        );
      }

      if (_currentCustomer?.id == customerId) {
        final current = _currentCustomer!;
        _currentCustomer = Customer(
          id: current.id,
          name: updatedCustomer.name,
          email: updatedCustomer.email,
          phone: updatedCustomer.phone,
          address: current.address,
          createdAt: current.createdAt,
          totalSpent: current.totalSpent,
          billCount: current.billCount,
        );
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

  Future<void> fetchCustomerHistory(String customerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _customerHistory = await ApiService.getCustomerHistory(customerId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectCustomer(String customerId) async {
    try {
      _currentCustomer = _customers.firstWhere((c) => c.id == customerId);
      await fetchCustomerHistory(customerId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearCurrentCustomer() {
    _currentCustomer = null;
    _customerHistory = [];
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Customer? getCustomerById(String id) {
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }
}
