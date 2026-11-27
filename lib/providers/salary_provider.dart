import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class SalaryProvider extends ChangeNotifier {
  List<MonthlySalary> _salaries = [];
  bool _isLoading = false;
  String? _error;

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  List<MonthlySalary> get salaries => _salaries;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get selectedYear => _selectedYear;
  int get selectedMonth => _selectedMonth;

  Future<void> fetchMonthlySalaries({int? year, int? month}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (year != null) {
        _selectedYear = year;
      }
      if (month != null) {
        _selectedMonth = month;
      }

      _salaries = await ApiService.getMonthlySalaries(
        year: _selectedYear,
        month: _selectedMonth,
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

  Future<bool> saveMonthlySalary({
    required String userId,
    required int year,
    required int month,
    required double basicSalary,
    required double transportAllowance,
    required double bonus,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final saved = await ApiService.saveMonthlySalary(
        userId: userId,
        year: year,
        month: month,
        basicSalary: basicSalary,
        transportAllowance: transportAllowance,
        bonus: bonus,
      );

      final index = _salaries.indexWhere(
        (item) =>
            item.userId == saved.userId &&
            item.salaryYear == saved.salaryYear &&
            item.salaryMonth == saved.salaryMonth,
      );

      if (index >= 0) {
        _salaries[index] = saved;
      } else {
        _salaries.add(saved);
        _salaries.sort((a, b) => a.username.compareTo(b.username));
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

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
