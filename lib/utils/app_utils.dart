import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'constants.dart';

class AppUtils {
  static String _shopName = AppConstants.appName;
  static String _currencyLocale = 'en_IN';
  static String _currencySymbol = '₹';
  static int _currencyDecimalDigits = 2;
  static String _languageLocale = 'en';

  static NumberFormat _currencyFormat = NumberFormat.currency(
    locale: _currencyLocale,
    symbol: _currencySymbol,
    decimalDigits: _currencyDecimalDigits,
  );

  static String get shopName => _shopName;
  static String get currencyLocale => _currencyLocale;
  static String get languageLocale => _languageLocale;

  static void configureSettings({
    required String shopName,
    required String currencyLocale,
    required String currencySymbol,
    required int currencyDecimalDigits,
    required String languageLocale,
  }) {
    _shopName = shopName.trim().isEmpty ? AppConstants.appName : shopName.trim();
    _currencyLocale = currencyLocale;
    _currencySymbol = currencySymbol;
    _currencyDecimalDigits = currencyDecimalDigits;
    _languageLocale = languageLocale;

    _currencyFormat = NumberFormat.currency(
      locale: _currencyLocale,
      symbol: _currencySymbol,
      decimalDigits: _currencyDecimalDigits,
    );
  }

  // Number formatting
  static String formatCurrency(double amount) {
    return _currencyFormat.format(amount);
  }

  static String formatPercentage(double percentage) {
    return '${(percentage * 100).toStringAsFixed(1)}%';
  }

  // Date formatting
  static String formatDate(DateTime date) {
    return DateFormat.yMd(_languageLocale).format(date);
  }

  static String formatDateTime(DateTime dateTime) {
    return DateFormat.yMd(_languageLocale).add_Hm().format(dateTime);
  }

  // Validation
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  static bool isValidPhone(String phone) {
    return phone.length >= 10 && phone.length <= 15;
  }

  static bool isValidSKU(String sku) {
    return sku.isNotEmpty && sku.length <= 50;
  }

  // Error handling
  static void showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.errorColor,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.successColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showWarningSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.warningColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Calculations
  static double calculateTax(double subtotal, double taxRate) {
    return subtotal * taxRate;
  }

  static double calculateTotal(double subtotal, double tax) {
    return subtotal + tax;
  }

  static double calculateDiscount(double amount, double discountPercentage) {
    return amount * (1 - discountPercentage);
  }

  // String utilities
  static String capitalizeFirstLetter(String text) {
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  static String truncateString(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // Generate random ID
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Color utilities
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
        return AppConstants.successColor;
      case 'pending':
        return AppConstants.warningColor;
      case 'cancelled':
      case 'failed':
        return AppConstants.errorColor;
      default:
        return Colors.grey;
    }
  }

  static Color getStockStatusColor(int quantity, int reorderLevel) {
    if (quantity <= reorderLevel) {
      return AppConstants.errorColor;
    } else if (quantity <= reorderLevel * 2) {
      return AppConstants.warningColor;
    }
    return AppConstants.successColor;
  }
}
