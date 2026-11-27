import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/app_settings_provider.dart';
import 'providers/product_provider.dart';
import 'providers/bill_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/reports_provider.dart';
import 'providers/salary_provider.dart';
import 'screens/login_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/server_setup_screen.dart';
import 'screens/local_account_screen.dart';
import 'services/server_settings.dart';
import 'services/app_license.dart';
import 'utils/constants.dart';
import 'widgets/app_edition_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLicense.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServerSettings(),
      child: Consumer<ServerSettings>(
        builder: (context, server, _) => MultiProvider(
          key: ValueKey(server.address),
          providers: [
            ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => ProductProvider()),
            ChangeNotifierProvider(create: (_) => BillProvider()),
            ChangeNotifierProvider(create: (_) => CustomerProvider()),
            ChangeNotifierProvider(create: (_) => ReportsProvider()),
            ChangeNotifierProvider(create: (_) => SalaryProvider()),
          ],
          child: Consumer<AppSettingsProvider>(
            builder: (context, settingsProvider, _) {
              final effectiveTitle = settingsProvider.hasConfiguredShopName
                  ? settingsProvider.shopName
                  : AppConstants.appName;

              return MaterialApp(
                title: effectiveTitle,
                builder: (context, child) => AppEditionGate(
                  license: AppLicense.instance,
                  child: child!,
                ),
                onGenerateTitle: (_) => effectiveTitle,
                locale: settingsProvider.appLocale,
                supportedLocales: const [
                  Locale('en', 'IN'),
                  Locale('hi', 'IN'),
                  Locale('ta', 'IN'),
                  Locale('ar', 'AE'),
                ],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: ThemeData(
                  useMaterial3: true,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: AppConstants.primaryColor,
                    brightness: Brightness.light,
                  ),
                  fontFamily: 'OpenSans',
                ),
                home: Consumer2<ServerSettings, AuthProvider>(
                  builder: (context, server, authProvider, _) {
                    if (server.loading) {
                      return const Scaffold(
                          body: Center(child: CircularProgressIndicator()));
                    }
                    if (server.address == null)
                      return const ServerSetupScreen();
                    if (server.address == ServerSettings.localAddress) {
                      return const LocalAccountScreen();
                    }
                    if (!authProvider.isLoggedIn) return const LoginScreen();
                    if (authProvider.shouldPromptPasswordChange)
                      return const ChangePasswordScreen();
                    return const HomeScreen();
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
