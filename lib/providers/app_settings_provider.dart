import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_utils.dart';
import '../utils/constants.dart';

class CurrencyCountryOption {
  final String code;
  final String label;
  final String locale;
  final String symbol;
  final int decimalDigits;

  const CurrencyCountryOption({
    required this.code,
    required this.label,
    required this.locale,
    required this.symbol,
    this.decimalDigits = 2,
  });
}

class LanguageOption {
  final String code;
  final String label;
  final String locale;

  const LanguageOption({
    required this.code,
    required this.label,
    required this.locale,
  });
}

class AppSettingsProvider extends ChangeNotifier {
  static const String _shopNameKey = 'app_shop_name';
  static const String _shopEmailKey = 'app_shop_email';
  static const String _shopMobileKey = 'app_shop_mobile';
  static const String _currencyCountryCodeKey = 'app_currency_country_code';
  static const String _languageCodeKey = 'app_language_code';
  static const String _autoProductCodeKey = 'app_auto_product_code';

  static const List<CurrencyCountryOption> countries = [
    CurrencyCountryOption(
      code: 'IN',
      label: 'India (INR)',
      locale: 'en_IN',
      symbol: '₹',
    ),
    CurrencyCountryOption(
      code: 'US',
      label: 'United States (USD)',
      locale: 'en_US',
      symbol: r'$',
    ),
    CurrencyCountryOption(
      code: 'GB',
      label: 'United Kingdom (GBP)',
      locale: 'en_GB',
      symbol: '£',
    ),
    CurrencyCountryOption(
      code: 'AE',
      label: 'UAE (AED)',
      locale: 'en_AE',
      symbol: 'AED ',
    ),
    CurrencyCountryOption(
      code: 'EU',
      label: 'Eurozone (EUR)',
      locale: 'de_DE',
      symbol: '€',
    ),
  ];

  static const List<LanguageOption> languages = [
    LanguageOption(code: 'en', label: 'English', locale: 'en_IN'),
    LanguageOption(code: 'hi', label: 'Hindi', locale: 'hi_IN'),
    LanguageOption(code: 'ta', label: 'Tamil', locale: 'ta_IN'),
    LanguageOption(code: 'ar', label: 'Arabic', locale: 'ar_AE'),
  ];

  bool _isLoading = true;
  int _settingsVersion = 0;
  String _shopName = '';
  String _shopEmail = '';
  String _shopMobile = '';
  bool _autoProductCodeEnabled = false;
  CurrencyCountryOption _selectedCountry = countries.first;
  LanguageOption _selectedLanguage = languages.first;

  AppSettingsProvider() {
    _loadSettings();
  }

  bool get isLoading => _isLoading;
  int get settingsVersion => _settingsVersion;
  String get configuredShopName => _shopName;
  String get shopName => _shopName.trim().isEmpty ? AppConstants.appName : _shopName.trim();
  bool get hasConfiguredShopName => _shopName.trim().isNotEmpty;
  String get shopEmail => _shopEmail;
  String get shopMobile => _shopMobile;
  bool get autoProductCodeEnabled => _autoProductCodeEnabled;
  CurrencyCountryOption get selectedCountry => _selectedCountry;
  LanguageOption get selectedLanguage => _selectedLanguage;

  Locale get appLocale {
    final parts = _selectedLanguage.locale.split('_');
    if (parts.length >= 2) {
      return Locale(parts[0], parts[1]);
    }
    return Locale(parts[0]);
  }

  Future<void> saveSettings({
    required String shopName,
      required String shopEmail,
      required String shopMobile,
    required String countryCode,
    required String languageCode,
    required bool autoProductCodeEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    _shopName = shopName.trim();
    _shopEmail = shopEmail.trim();
    _shopMobile = shopMobile.trim();
    _autoProductCodeEnabled = autoProductCodeEnabled;
    _selectedCountry = _countryByCode(countryCode);
    _selectedLanguage = _languageByCode(languageCode);

    await prefs.setString(_shopNameKey, _shopName);
    await prefs.setString(_shopEmailKey, _shopEmail);
    await prefs.setString(_shopMobileKey, _shopMobile);
    await prefs.setBool(_autoProductCodeKey, _autoProductCodeEnabled);
    await prefs.setString(_currencyCountryCodeKey, _selectedCountry.code);
    await prefs.setString(_languageCodeKey, _selectedLanguage.code);

    _applyToAppUtils();
    _settingsVersion++;
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _shopName = (prefs.getString(_shopNameKey) ?? '').trim();
    _shopEmail = prefs.getString(_shopEmailKey) ?? '';
    _shopMobile = prefs.getString(_shopMobileKey) ?? '';
    _autoProductCodeEnabled = prefs.getBool(_autoProductCodeKey) ?? false;
    final countryCode = prefs.getString(_currencyCountryCodeKey) ?? countries.first.code;
    final languageCode = prefs.getString(_languageCodeKey) ?? languages.first.code;

    _selectedCountry = _countryByCode(countryCode);
    _selectedLanguage = _languageByCode(languageCode);

    _applyToAppUtils();

    _isLoading = false;
    _settingsVersion++;
    notifyListeners();
  }

  CurrencyCountryOption _countryByCode(String code) {
    for (final option in countries) {
      if (option.code == code) {
        return option;
      }
    }
    return countries.first;
  }

  LanguageOption _languageByCode(String code) {
    for (final option in languages) {
      if (option.code == code) {
        return option;
      }
    }
    return languages.first;
  }

  void _applyToAppUtils() {
    AppUtils.configureSettings(
      shopName: _shopName,
      currencyLocale: _selectedCountry.locale,
      currencySymbol: _selectedCountry.symbol,
      currencyDecimalDigits: _selectedCountry.decimalDigits,
      languageLocale: _selectedLanguage.locale,
    );
  }
}
