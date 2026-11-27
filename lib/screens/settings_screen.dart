import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_settings_provider.dart';
import '../services/api_service.dart';
import '../utils/app_utils.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _shopNameController;
  late TextEditingController _shopEmailController;
  late TextEditingController _shopMobileController;
  late TextEditingController _twilioSidController;
  late TextEditingController _twilioTokenController;
  late TextEditingController _twilioFromController;
  late TextEditingController _smsCountryCodeController;
  late TextEditingController _smtpHostController;
  late TextEditingController _smtpPortController;
  late TextEditingController _smtpUserController;
  late TextEditingController _smtpPasswordController;
  late TextEditingController _smtpFromController;
  String? _selectedCountryCode;
  String? _selectedLanguageCode;
  bool _autoProductCodeEnabled = false;
  bool _initialized = false;
  bool _providerLoading = false;
  bool _smsProviderEnabled = false;
  bool _emailProviderEnabled = false;
  static const String _defaultGmailSmtpHost = 'smtp.gmail.com';
  static const String _defaultGmailSmtpPort = '587';

  @override
  void initState() {
    super.initState();
    _shopNameController = TextEditingController();
    _shopEmailController = TextEditingController();
    _shopMobileController = TextEditingController();
    _twilioSidController = TextEditingController();
    _twilioTokenController = TextEditingController();
    _twilioFromController = TextEditingController();
    _smsCountryCodeController = TextEditingController(text: '+91');
    _smtpHostController = TextEditingController(text: _defaultGmailSmtpHost);
    _smtpPortController = TextEditingController(text: _defaultGmailSmtpPort);
    _smtpUserController = TextEditingController();
    _smtpPasswordController = TextEditingController();
    _smtpFromController = TextEditingController();
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopEmailController.dispose();
    _shopMobileController.dispose();
    _twilioSidController.dispose();
    _twilioTokenController.dispose();
    _twilioFromController.dispose();
    _smsCountryCodeController.dispose();
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    _smtpUserController.dispose();
    _smtpPasswordController.dispose();
    _smtpFromController.dispose();
    super.dispose();
  }

  Future<void> _loadProviderConfig() async {
    setState(() {
      _providerLoading = true;
    });

    try {
      final config = await ApiService.getNotificationProviderConfig();
      if (!mounted) {
        return;
      }
      setState(() {
        _smsProviderEnabled = config['sms_enabled'] == true;
        _emailProviderEnabled = config['email_enabled'] == true;
        // Note: autoProductCodeEnabled is NOT loaded here to avoid race condition
        // It uses the provider's built-in setting which loads from SharedPreferences
        _twilioSidController.text = (config['twilio_account_sid'] ?? '').toString();
        _twilioTokenController.text = (config['twilio_auth_token'] ?? '').toString();
        _twilioFromController.text = (config['twilio_from_number'] ?? '').toString();
        _smsCountryCodeController.text = (config['sms_default_country_code'] ?? '+91').toString();
        final smtpHost = (config['smtp_host'] ?? '').toString().trim();
        final smtpPort = (config['smtp_port'] ?? '').toString().trim();
        final smtpUser = (config['smtp_username'] ?? '').toString().trim();
        final smtpFrom = (config['smtp_from'] ?? '').toString().trim();

        _smtpHostController.text = smtpHost.isNotEmpty ? smtpHost : _defaultGmailSmtpHost;
        _smtpPortController.text = smtpPort.isNotEmpty ? smtpPort : _defaultGmailSmtpPort;
        _smtpUserController.text = smtpUser;
        _smtpPasswordController.text = (config['smtp_password'] ?? '').toString();
        _smtpFromController.text = smtpFrom.isNotEmpty ? smtpFrom : smtpUser;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load provider settings: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _providerLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();

    if (settings.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_initialized) {
      _shopNameController.text = settings.configuredShopName;
      _shopEmailController.text = settings.shopEmail;
      _shopMobileController.text = settings.shopMobile;
      _selectedCountryCode = settings.selectedCountry.code;
      _selectedLanguageCode = settings.selectedLanguage.code;
      _autoProductCodeEnabled = settings.autoProductCodeEnabled;
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadProviderConfig();
        }
      });
    }

    _selectedCountryCode ??= settings.selectedCountry.code;
    _selectedLanguageCode ??= settings.selectedLanguage.code;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Store Settings',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _shopNameController,
                        decoration: const InputDecoration(
                          labelText: 'Shop Name',
                          hintText: 'Enter your shop name for bills and title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _shopEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Shop Email (Optional)',
                          hintText: 'Enter shop email to display on bills',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _shopMobileController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Shop Mobile (Optional)',
                          hintText: 'Enter shop mobile to display on bills',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedCountryCode,
                        decoration: const InputDecoration(
                          labelText: 'Country (Currency Format)',
                          border: OutlineInputBorder(),
                        ),
                        items: AppSettingsProvider.countries
                            .map(
                              (country) => DropdownMenuItem<String>(
                                value: country.code,
                                child: Text(country.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCountryCode = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedLanguageCode,
                        decoration: const InputDecoration(
                          labelText: 'Language',
                          border: OutlineInputBorder(),
                        ),
                        items: AppSettingsProvider.languages
                            .map(
                              (language) => DropdownMenuItem<String>(
                                value: language.code,
                                child: Text(language.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedLanguageCode = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Auto-generate Product Code'),
                        subtitle: const Text('New products will use format like P0000000001'),
                        value: _autoProductCodeEnabled,
                        onChanged: (value) {
                          setState(() {
                            _autoProductCodeEnabled = value ?? false;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Language is applied immediately for app locale and bill date display. For Tamil typing in User, Customer, and Stock forms, enable Tamil keyboard/input source in your device or browser input settings.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              final countryCode = _selectedCountryCode ?? settings.selectedCountry.code;
                              final languageCode = _selectedLanguageCode ?? settings.selectedLanguage.code;
                              final autoProductCodeEnabled = _autoProductCodeEnabled;

                              await context.read<AppSettingsProvider>().saveSettings(
                                    shopName: _shopNameController.text,
                                    shopEmail: _shopEmailController.text,
                                    shopMobile: _shopMobileController.text,
                                    countryCode: countryCode,
                                    languageCode: languageCode,
                                    autoProductCodeEnabled: autoProductCodeEnabled,
                                  );

                              try {
                                await ApiService.updateNotificationProviderConfig(
                                  smsEnabled: _smsProviderEnabled,
                                  emailEnabled: _emailProviderEnabled,
                                  autoProductCodeEnabled: autoProductCodeEnabled,
                                  twilioAccountSid: _twilioSidController.text,
                                  twilioAuthToken: _twilioTokenController.text,
                                  twilioFromNumber: _twilioFromController.text,
                                  smsDefaultCountryCode: _smsCountryCodeController.text,
                                  smtpHost: _smtpHostController.text,
                                  smtpPort: _smtpPortController.text,
                                  smtpUsername: _smtpUserController.text,
                                  smtpPassword: _smtpPasswordController.text,
                                  smtpFrom: _smtpFromController.text.trim().isNotEmpty
                                      ? _smtpFromController.text
                                      : _smtpUserController.text,
                                );
                              } catch (_) {
                                // Local save is already done; backend sync can be retried from provider settings.
                              }

                              if (!mounted) {
                                return;
                              }
                              setState(() {
                                _autoProductCodeEnabled = autoProductCodeEnabled;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Settings saved successfully')),
                              );
                            },
                            icon: const Icon(Icons.save),
                            label: const Text('Save Settings'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SMS Provider (Twilio)',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Enable SMS Provider'),
                        value: _smsProviderEnabled,
                        onChanged: (value) {
                          setState(() {
                            _smsProviderEnabled = value ?? false;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _twilioSidController,
                        decoration: const InputDecoration(
                          labelText: 'Twilio Account SID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _twilioTokenController,
                        decoration: const InputDecoration(
                          labelText: 'Twilio Auth Token',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _twilioFromController,
                        decoration: const InputDecoration(
                          labelText: 'Twilio From Number',
                          hintText: '+1XXXXXXXXXX',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _smsCountryCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Default SMS Country Code',
                          hintText: '+91',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Email Provider (SMTP)',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Enable Email Provider'),
                        value: _emailProviderEnabled,
                        onChanged: (value) {
                          setState(() {
                            _emailProviderEnabled = value ?? false;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _smtpHostController,
                        decoration: const InputDecoration(
                          labelText: 'SMTP Host',
                          hintText: 'smtp.gmail.com',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _smtpPortController,
                        decoration: const InputDecoration(
                          labelText: 'SMTP Port',
                          hintText: '587',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _smtpUserController,
                        decoration: const InputDecoration(
                          labelText: 'SMTP Username',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _smtpPasswordController,
                        decoration: const InputDecoration(
                          labelText: 'SMTP Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _smtpFromController,
                        decoration: const InputDecoration(
                          labelText: 'SMTP From Email',
                          hintText: 'yourname@gmail.com',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _providerLoading
                                ? null
                                : () async {
                                    try {
                                      await ApiService.updateNotificationProviderConfig(
                                        smsEnabled: _smsProviderEnabled,
                                        emailEnabled: _emailProviderEnabled,
                                        autoProductCodeEnabled: _autoProductCodeEnabled,
                                        twilioAccountSid: _twilioSidController.text,
                                        twilioAuthToken: _twilioTokenController.text,
                                        twilioFromNumber: _twilioFromController.text,
                                        smsDefaultCountryCode: _smsCountryCodeController.text,
                                        smtpHost: _smtpHostController.text,
                                        smtpPort: _smtpPortController.text,
                                        smtpUsername: _smtpUserController.text,
                                        smtpPassword: _smtpPasswordController.text,
                                        smtpFrom: _smtpFromController.text.trim().isNotEmpty
                                            ? _smtpFromController.text
                                            : _smtpUserController.text,
                                      );
                                      if (!mounted) {
                                        return;
                                      }
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Provider settings saved successfully')),
                                      );
                                    } catch (e) {
                                      if (!mounted) {
                                        return;
                                      }
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to save provider settings: $e')),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.save),
                            label: const Text('Save Provider Settings'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _providerLoading ? null : _loadProviderConfig,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reload Provider Settings'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preview',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Text('Shop: ${AppUtils.shopName}'),
                      Text('Currency Example: ${AppUtils.formatCurrency(12345.67)}'),
                      Text('Date Example: ${AppUtils.formatDateTime(DateTime.now())}'),
                    ],
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
