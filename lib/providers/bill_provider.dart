import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class BillProvider extends ChangeNotifier {
  List<Bill> _openBills = [];
  String? _activeBillId;
  List<Bill> _bills = [];
  bool _isLoading = false;
  String? _error;
  double _taxRate = 0.10; // 10% tax

  Bill? get currentBill {
    if (_openBills.isEmpty) {
      return null;
    }

    if (_activeBillId == null) {
      return _openBills.first;
    }

    return _openBills.firstWhere(
      (bill) => bill.id == _activeBillId,
      orElse: () => _openBills.first,
    );
  }

  List<Bill> get openBills => _openBills;
  String? get activeBillId => _activeBillId;
  List<Bill> get bills => _bills;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get taxRate => _taxRate;

  double get currentSubtotal =>
      currentBill?.items.fold<double>(0.0, (sum, item) => sum + item.subtotal) ?? 0.0;

  double get currentTax => currentSubtotal * _taxRate;

  double get currentTotal => currentSubtotal + currentTax;

  int get currentItemCount => currentBill?.items.length ?? 0;

  Future<void> loadOpenBills() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _openBills = await ApiService.getDraftBills();
      if (_openBills.isNotEmpty) {
        _activeBillId ??= _openBills.first.id;
      } else {
        _activeBillId = null;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createNewBill(String customerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final draft = await ApiService.createDraftBill(
        customerId == 'guest' ? null : int.tryParse(customerId),
      );
      _openBills = [draft, ..._openBills];
      _activeBillId = draft.id;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addItemToCurrentBill(String productId, int quantity) async {
    final active = currentBill;
    if (active == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedDraft = await ApiService.addItemToDraftBill(
        active.id,
        productId,
        quantity,
      );

      _replaceOpenBill(updatedDraft);

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

  Future<bool> removeItemFromBill(String itemId) async {
    final active = currentBill;
    if (active == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedDraft = await ApiService.removeItemFromDraftBill(active.id, itemId);
      _replaceOpenBill(updatedDraft);

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

  Future<bool> updateItemQuantityInBill(String productId, int quantity) async {
    final active = currentBill;
    if (active == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedDraft = await ApiService.updateDraftItemQuantity(
        active.id,
        productId,
        quantity,
      );
      _replaceOpenBill(updatedDraft);
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

  Future<bool> checkout(double paidAmount, String paymentMethod) async {
    final active = currentBill;
    if (active == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await ApiService.checkoutDraftBill(
        active.id,
        currentTax,
        paymentMethod,
      );

      final completedBill = active.copyWith(
        id: result['bill_id']?.toString() ?? active.id,
        subtotal: result['subtotal'] is num ? (result['subtotal'] as num).toDouble() : currentSubtotal,
        taxAmount: result['tax'] is num ? (result['tax'] as num).toDouble() : currentTax,
        total: result['total'] is num ? (result['total'] as num).toDouble() : currentTotal,
        status: BillStatus.completed,
        paymentMethod: paymentMethod,
      );

      _openBills.removeWhere((bill) => bill.id == active.id);
      _activeBillId = _openBills.isNotEmpty ? _openBills.first.id : null;
      _bills = [completedBill, ..._bills];
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

  Future<void> switchToBill(String billId) async {
    _activeBillId = billId;
    notifyListeners();
  }

  Future<bool> closeBill(String billId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiService.deleteDraftBill(billId);
      _openBills.removeWhere((bill) => bill.id == billId);

      if (_activeBillId == billId) {
        _activeBillId = _openBills.isNotEmpty ? _openBills.first.id : null;
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

  Future<void> updateCurrentBillCustomer(String customerId) async {
    final active = currentBill;
    if (active == null) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await ApiService.updateDraftBillCustomer(
        active.id,
        customerId == 'guest' ? null : int.tryParse(customerId),
      );
      _replaceOpenBill(updated);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchBills({DateTime? startDate, DateTime? endDate}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _bills = await ApiService.getBills(startDate: startDate, endDate: endDate);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> getReceipt(String billId) async {
    try {
      return await ApiService.getReceipt(billId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return '';
    }
  }

  void clearCurrentBill() {
    _activeBillId = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Bill? copyWith({
    String? id,
    String? customerId,
    double? subtotal,
    double? taxAmount,
    double? total,
    BillStatus? status,
    String? paymentMethod,
    DateTime? createdAt,
    List<BillItem>? items,
  }) {
    final active = currentBill;
    return active?.copyWith(
      id: id ?? active.id,
      customerId: customerId ?? active.customerId,
      subtotal: subtotal ?? active.subtotal,
      taxAmount: taxAmount ?? active.taxAmount,
      total: total ?? active.total,
      status: status ?? active.status,
      paymentMethod: paymentMethod ?? active.paymentMethod,
      createdAt: createdAt ?? active.createdAt,
      items: items ?? active.items,
    );
  }

  void _replaceOpenBill(Bill updated) {
    final index = _openBills.indexWhere((bill) => bill.id == updated.id);
    if (index >= 0) {
      _openBills[index] = updated;
    } else {
      _openBills = [updated, ..._openBills];
    }

    _activeBillId ??= updated.id;
  }
}

extension BillCopyWith on Bill {
  Bill copyWith({
    String? id,
    String? customerId,
    double? subtotal,
    double? taxAmount,
    double? total,
    BillStatus? status,
    String? paymentMethod,
    DateTime? createdAt,
    List<BillItem>? items,
  }) {
    return Bill(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }
}
