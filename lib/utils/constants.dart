import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'SwiftMart';
  static const String appVersion = '1.0.0';

  // Colors
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF03DAC6);
  static const Color errorColor = Color(0xFFB00020);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFFC107);

  // API
  static const String apiBaseUrl = '/api';
  static const int apiTimeout = 30; // seconds

  // Tax rate
  static const double taxRate = 0.10; // 10%

  // Default values
  static const int defaultReorderLevel = 10;
  static const String defaultPaymentMethod = 'cash';

  // Error messages
  static const String errorNetworkConnection = 'Network connection error';
  static const String errorServerError = 'Server error occurred';
  static const String errorUnauthorized = 'Unauthorized access';
  static const String errorNotFound = 'Resource not found';

  // Success messages
  static const String successLogin = 'Login successful';
  static const String successLogout = 'Logged out successfully';
  static const String successProductAdded = 'Product added successfully';
  static const String successProductUpdated = 'Product updated successfully';
  static const String successCustomerAdded = 'Customer added successfully';
  static const String successBillCreated = 'Bill created successfully';
  static const String successCheckout = 'Checkout completed successfully';
}
