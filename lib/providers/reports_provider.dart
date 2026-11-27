import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ReportsProvider extends ChangeNotifier {
  SalesReport? _dailyReport;
  List<SalesReport> _monthlyReports = [];
  Map<String, dynamic>? _profitLossReport;
  Map<String, dynamic>? _investmentReturnReport;
  Map<String, dynamic>? _manualFinanceEntry;
  bool _isLoading = false;
  String? _error;

  SalesReport? get dailyReport => _dailyReport;
  List<SalesReport> get monthlyReports => _monthlyReports;
  Map<String, dynamic>? get profitLossReport => _profitLossReport;
  Map<String, dynamic>? get investmentReturnReport => _investmentReturnReport;
  Map<String, dynamic>? get manualFinanceEntry => _manualFinanceEntry;
  List<Map<String, dynamic>> get profitLossTrend {
    final raw = (_profitLossReport?['trend'] as List<dynamic>? ?? []);
    return raw
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  List<Map<String, dynamic>> get investmentReturnTrend {
    final raw = (_investmentReturnReport?['trend'] as List<dynamic>? ?? []);
    return raw
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalMonthlySales =>
      _monthlyReports.fold(0.0, (sum, report) => sum + report.totalSales);

  int get totalMonthlyBills =>
      _monthlyReports.fold(0, (sum, report) => sum + report.billCount);

  double get totalMonthlyTax =>
      _monthlyReports.fold(0.0, (sum, report) => sum + report.taxCollected);

  Future<void> fetchDailySalesReport(DateTime date) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _dailyReport = await ApiService.getDailySalesReport(date);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMonthlySalesReport(int year, int month) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _monthlyReports = await ApiService.getMonthlySalesReport(year, month);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchProfitLossReport(
    int year,
    int month,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profitLossReport = await ApiService.getProfitLossReport(
        year,
        month,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchInvestmentReturnReport(
    int year,
    int month,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _investmentReturnReport = await ApiService.getInvestmentReturnReport(
        year,
        month,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchManualFinanceEntry(int year, int month) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _manualFinanceEntry = await ApiService.getManualFinanceEntry(year, month);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveManualFinanceEntry({
    required int year,
    required int month,
    required double manualInvestment,
    required double manualProfitAdjustment,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _manualFinanceEntry = await ApiService.saveManualFinanceEntry(
        year: year,
        month: month,
        manualInvestment: manualInvestment,
        manualProfitAdjustment: manualProfitAdjustment,
      );
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

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Map<String, dynamic> getDailyStats() {
    if (_dailyReport == null) {
      return {
        'totalSales': 0.0,
        'billCount': 0,
        'averageBill': 0.0,
        'taxCollected': 0.0,
      };
    }

    return {
      'totalSales': _dailyReport!.totalSales,
      'billCount': _dailyReport!.billCount,
      'averageBill': _dailyReport!.averageBillAmount,
      'taxCollected': _dailyReport!.taxCollected,
    };
  }

  Map<String, dynamic> getMonthlyStats() {
    return {
      'totalSales': totalMonthlySales,
      'billCount': totalMonthlyBills,
      'averageBill':
          totalMonthlyBills > 0 ? totalMonthlySales / totalMonthlyBills : 0.0,
      'taxCollected': totalMonthlyTax,
    };
  }
}
