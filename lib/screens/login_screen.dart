import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/app_settings_provider.dart';
import '../services/api_service.dart';
import '../services/server_settings.dart';
import '../utils/constants.dart';
import 'customer_shop_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late FocusNode _usernameFocusNode;
  late FocusNode _passwordFocusNode;
  late AnimationController _introController;
  late AnimationController _logoPulseController;
  late Animation<double> _titleFade;
  late Animation<double> _formFade;
  late Animation<Offset> _formSlide;
  late Animation<double> _logoPulse;
  bool _showDefaultAdminHint = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _usernameFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );

    _titleFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _formFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
    );
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
    );
    _logoPulse = Tween<double>(begin: 0.96, end: 1.05).animate(
      CurvedAnimation(parent: _logoPulseController, curve: Curves.easeInOut),
    );

    _introController.forward();
    _logoPulseController.repeat(reverse: true);
    _loadSetupStatus();
  }

  Future<void> _loadSetupStatus() async {
    try {
      final showHint = await ApiService.shouldShowDefaultAdminHint();
      if (!mounted) {
        return;
      }
      setState(() => _showDefaultAdminHint = showHint);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _showDefaultAdminHint = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _introController.dispose();
    _logoPulseController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin(AuthProvider authProvider) async {
    if (authProvider.isLoading) {
      return;
    }

    final success = await authProvider.login(
      _usernameController.text,
      _passwordController.text,
    );

    if (success && mounted) {
      FocusScope.of(context).unfocus();
      context.read<AuthProvider>();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final shopName = settings.hasConfiguredShopName
        ? settings.shopName
        : AppConstants.appName;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppConstants.primaryColor,
              AppConstants.primaryColor.withOpacity(0.7),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Title
                  ScaleTransition(
                    scale: _logoPulse,
                    child: const Icon(
                      Icons.shopping_cart,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _titleFade,
                    child: Text(
                      shopName,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  FadeTransition(
                    opacity: _titleFade,
                    child: Text(
                      'The future of smart retail starts with your next great sale.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Login Form
                  FadeTransition(
                    opacity: _formFade,
                    child: SlideTransition(
                      position: _formSlide,
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Consumer<AuthProvider>(
                            builder: (context, authProvider, _) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              // Username field
                              TextField(
                                controller: _usernameController,
                                focusNode: _usernameFocusNode,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) {
                                  FocusScope.of(context).requestFocus(_passwordFocusNode);
                                },
                                decoration: InputDecoration(
                                  hintText: 'Username',
                                  prefixIcon: const Icon(Icons.person),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Password field
                              TextField(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submitLogin(authProvider),
                                decoration: InputDecoration(
                                  hintText: 'Password',
                                  prefixIcon: const Icon(Icons.lock),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Error message
                              if (authProvider.error != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red),
                                  ),
                                  child: Text(
                                    authProvider.error!,
                                    style: TextStyle(color: Colors.red.shade700),
                                  ),
                                ),
                              if (authProvider.error != null)
                                const SizedBox(height: 16),

                              // Login button
                              ElevatedButton(
                                onPressed: authProvider.isLoading
                                    ? null
                                    : () => _submitLogin(authProvider),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConstants.primaryColor,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: authProvider.isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation(Colors.white),
                                        ),
                                      )
                                    : Text(
                                      'Login',
                                        style:
                                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                      ),
                              ),

                                  TextButton(
                                    onPressed: () => context.read<ServerSettings>().edit(),
                                    child: const Text('Change server'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const CustomerShopScreen(),
                                      ),
                                    ),
                                    child: const Text('Shop as a customer'),
                                  ),
                                  const SizedBox(height: 16),

                                  // Setup hint
                                  if (_showDefaultAdminHint)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue),
                                      ),
                                      child: Text(
                                        'Default admin: admin / admin',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
