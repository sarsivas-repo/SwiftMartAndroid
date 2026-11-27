import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/product_provider.dart';
import '../providers/reports_provider.dart';
import '../providers/customer_provider.dart';
import '../screens/pos_screen.dart';
import '../screens/stock_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/customers_screen.dart';
import '../screens/salary_screen.dart';
import '../screens/user_management_screen.dart';
import '../screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  TabController? _tabController;
  int _selectedTab = 0;
  static const double _desktopTabCardWidth = 132;

  @override
  void initState() {
    super.initState();

    // Load initial data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();

      if (authProvider.isAdmin || authProvider.isCashier) {
        context.read<ProductProvider>().fetchProducts();
        context.read<CustomerProvider>().fetchCustomers();
      }

      if (authProvider.isAdmin) {
        context.read<ReportsProvider>().fetchDailySalesReport(DateTime.now());
      }

      if (authProvider.isAdmin) {
        authProvider.fetchUsers();
      }
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  List<_DashboardTab> _getTabs(AuthProvider authProvider) {
    final tabs = <_DashboardTab>[];

    if (authProvider.isAdmin || authProvider.isCashier) {
      tabs.add(
        const _DashboardTab(
          title: 'Sales',
          icon: Icons.shopping_cart,
          screen: POSScreen(),
        ),
      );
    }

    if (authProvider.isAdmin) {
      tabs.addAll(const [
        _DashboardTab(
          title: 'Stock',
          icon: Icons.warehouse,
          screen: StockScreen(),
        ),
      ]);
    }

    if (authProvider.isAdmin) {
      tabs.add(
        const _DashboardTab(
          title: 'Customers',
          icon: Icons.people,
          screen: CustomersScreen(),
        ),
      );
    }

    if (authProvider.isManager) {
      tabs.add(
        const _DashboardTab(
          title: 'Stock',
          icon: Icons.warehouse,
          screen: StockScreen(showHeaderWithUserBadge: true),
        ),
      );
    }

    if (authProvider.isAdmin) {
      tabs.add(
        const _DashboardTab(
          title: 'Users',
          icon: Icons.admin_panel_settings,
          screen: UserManagementScreen(),
        ),
      );
      tabs.add(
        const _DashboardTab(
          title: 'Salary',
          icon: Icons.payments,
          screen: SalaryScreen(),
        ),
      );
      tabs.add(
        const _DashboardTab(
          title: 'Reports',
          icon: Icons.bar_chart,
          screen: ReportsScreen(),
        ),
      );
      tabs.add(
        const _DashboardTab(
          title: 'Settings',
          icon: Icons.settings,
          screen: SettingsScreen(),
        ),
      );
    }

    return tabs;
  }

  void _syncTabControllerLength(int length) {
    final currentLength = _tabController?.length;
    if (_tabController == null || currentLength != length) {
      _tabController?.dispose();
      _tabController = TabController(length: length, vsync: this);
      _selectedTab = 0;
      _tabController!.addListener(() {
        if (!mounted) {
          return;
        }
        final nextIndex = _tabController!.index;
        if (_selectedTab != nextIndex) {
          setState(() {
            _selectedTab = nextIndex;
          });
        }
      });
    }
  }

  Color _tabColor(String title) {
    switch (title) {
      case 'Sales':
        return Colors.blue;
      case 'Stock':
        return Colors.orange;
      case 'Reports':
        return Colors.purple;
      case 'Customers':
        return Colors.teal;
      case 'Salary':
        return Colors.green;
      case 'Users':
        return Colors.indigo;
      case 'Settings':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  List<Color> _tabGradient(String title) {
    switch (title) {
      case 'Sales':
        return const [Color(0xFF1E88E5), Color(0xFF42A5F5)];
      case 'Stock':
        return const [Color(0xFFF57C00), Color(0xFFFFB74D)];
      case 'Reports':
        return const [Color(0xFF8E24AA), Color(0xFFBA68C8)];
      case 'Customers':
        return const [Color(0xFF00897B), Color(0xFF4DB6AC)];
      case 'Salary':
        return const [Color(0xFF2E7D32), Color(0xFF66BB6A)];
      case 'Users':
        return const [Color(0xFF3949AB), Color(0xFF7986CB)];
      case 'Settings':
        return const [Color(0xFF6D4C41), Color(0xFFA1887F)];
      default:
        return const [Color(0xFF616161), Color(0xFF9E9E9E)];
    }
  }

  Widget _buildColoredTab(_DashboardTab tab, int index) {
    final color = _tabColor(tab.title);
    final gradientColors = _tabGradient(tab.title);
    final isSelected = (_tabController?.index ?? 0) == index;

    return Tab(
      child: SizedBox(
        width: _desktopTabCardWidth,
        child: AnimatedScale(
          scale: isSelected ? 1.0 : 0.96,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(colors: gradientColors)
                  : LinearGradient(
                      colors: [
                        gradientColors.first.withValues(alpha: 0.14),
                        gradientColors.last.withValues(alpha: 0.14),
                      ],
                    ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : color.withValues(alpha: 0.35),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: gradientColors.first.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  tab.icon,
                  size: 16,
                  color: isSelected ? Colors.white : color,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    tab.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? Colors.white : color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserBadge(AuthProvider authProvider, {bool compact = false}) {
    final user = authProvider.user;
    final username = authProvider.user?.username ?? 'User';
    final role = authProvider.user?.roleSummary ?? 'Role';
    final email = (user?.email ?? '').trim().isEmpty ? 'Not available' : user!.email;
    final mobile = (user?.mobile ?? '').trim().isEmpty ? 'Not available' : user!.mobile;

    return Tooltip(
      waitDuration: const Duration(milliseconds: 150),
      message: 'Username: $username\nEmail: $email\nMobile: $mobile',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showProfileDialog(),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: compact ? 12 : 13,
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(
                    Icons.person,
                    size: compact ? 14 : 15,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 9 : 10,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: compact ? 20 : 22,
                  color: Colors.grey.shade300,
                ),
                IconButton(
                  tooltip: 'Logout',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    context.read<AuthProvider>().logout();
                  },
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showProfileDialog() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      return;
    }

    final emailController = TextEditingController(text: user.email);
    final mobileController = TextEditingController(text: user.mobile);
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    Future<void> submit(BuildContext dialogContext) async {
      final email = emailController.text.trim();
      final mobile = mobileController.text.trim();
      final currentPassword = currentPasswordController.text;
      final newPassword = newPasswordController.text;
      final confirmPassword = confirmPasswordController.text;
      final wantsPasswordChange =
          currentPassword.isNotEmpty || newPassword.isNotEmpty || confirmPassword.isNotEmpty;

      if (email.isEmpty || mobile.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email and mobile number are required')),
        );
        return;
      }

      if (wantsPasswordChange) {
        if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fill all password fields to change password')),
          );
          return;
        }
        if (newPassword != confirmPassword) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New password and confirm password must match')),
          );
          return;
        }
        if (newPassword.length < 4) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password must be at least 4 characters')),
          );
          return;
        }
      }

      final profileUpdated = await auth.updateMyProfile(email: email, mobile: mobile);
      if (!profileUpdated) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.error ?? 'Failed to update profile')),
        );
        return;
      }

      if (wantsPasswordChange) {
        final passwordUpdated = await auth.changeOwnPassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
        if (!mounted) {
          return;
        }
        if (!passwordUpdated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(auth.error ?? 'Failed to update password')),
          );
          return;
        }
      }

      if (!mounted) {
        return;
      }

      Navigator.of(dialogContext).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wantsPasswordChange
                ? 'Profile and password updated successfully'
                : 'Profile updated successfully',
          ),
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile number'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Current password'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm new password'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => submit(dialogContext),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final authProvider = context.watch<AuthProvider>();
    final settingsVersion = context.watch<AppSettingsProvider>().settingsVersion;
    final tabs = _getTabs(authProvider);
    final hasSingleTab = tabs.length == 1;

    if (tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const SizedBox.shrink(),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildUserBadge(authProvider, compact: true),
            ),
          ],
        ),
        body: const Center(
          child: Text('No pages available for your role'),
        ),
      );
    }

    if (hasSingleTab) {
      return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          body: tabs.first.screen,
        ),
      );
    }

    _syncTabControllerLength(tabs.length);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: isMobile
            ? AppBar(
                title: const SizedBox.shrink(),
                elevation: 0,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildUserBadge(authProvider, compact: true),
                  ),
                ],
              )
            : AppBar(
                toolbarHeight: 0,
                elevation: 0,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(62),
                  child: Container(
                    height: 62,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey.shade50,
                          Colors.blueGrey.shade50,
                        ],
                      ),
                      border: Border(
                        top: BorderSide(color: Colors.blueGrey.shade100),
                        bottom: BorderSide(color: Colors.blueGrey.shade200),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            onTap: (index) {
                              setState(() {
                                _selectedTab = index;
                              });
                            },
                            dividerColor: Colors.transparent,
                            indicatorColor: Colors.transparent,
                            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                            indicatorSize: TabBarIndicatorSize.label,
                            tabs: tabs
                                .asMap()
                                .entries
                                .map((entry) => _buildColoredTab(entry.value, entry.key))
                                .toList(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildUserBadge(authProvider),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        body: isMobile ? _buildMobileLayout(tabs) : _buildWebLayout(tabs),
        bottomNavigationBar: isMobile
            ? BottomNavigationBar(
                currentIndex: _selectedTab,
                onTap: (index) {
                  setState(() {
                    _selectedTab = index;
                  });
                },
                type: BottomNavigationBarType.fixed,
                items: tabs
                    .map(
                      (tab) => BottomNavigationBarItem(
                        icon: Icon(tab.icon),
                        label: tab.title,
                      ),
                    )
                    .toList(),
              )
            : null,
      ),
    );
  }

  Widget _buildMobileLayout(List<_DashboardTab> tabs) {
    final settingsVersion = context.watch<AppSettingsProvider>().settingsVersion;
    return KeyedSubtree(
      key: ValueKey('mobile-tab-$settingsVersion-$_selectedTab'),
      child: tabs[_selectedTab].screen,
    );
  }

  Widget _buildWebLayout(List<_DashboardTab> tabs) {
    final settingsVersion = context.watch<AppSettingsProvider>().settingsVersion;
    return TabBarView(
      key: ValueKey('web-tabs-$settingsVersion'),
      controller: _tabController,
      children: tabs.map((tab) => tab.screen).toList(),
    );
  }
}

class _DashboardTab {
  final String title;
  final IconData icon;
  final Widget screen;

  const _DashboardTab({
    required this.title,
    required this.icon,
    required this.screen,
  });
}
