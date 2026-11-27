import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/salary_provider.dart';
import '../models/models.dart';

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({Key? key}) : super(key: key);

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  static const double _controlHeight = 56;
  static const double _controlRadius = 8;
  static const double _actionButtonSize = 40;
  static const BorderSide _enabledBorderSide =
      BorderSide(color: Color(0xFFBDBDBD));
  static const BorderSide _focusedBorderSide =
      BorderSide(color: Color(0xFF1976D2), width: 1.5);

  String? _selectedUserId;
  String _searchQuery = '';
  late TextEditingController _basicController;
  late TextEditingController _transportController;
  late TextEditingController _bonusController;

  @override
  void initState() {
    super.initState();
    _basicController = TextEditingController(text: '0');
    _transportController = TextEditingController(text: '0');
    _bonusController = TextEditingController(text: '0');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      if (auth.users.isEmpty) {
        await auth.fetchUsers();
      }

      if (!mounted) {
        return;
      }

      final salaryProvider = context.read<SalaryProvider>();
      await salaryProvider.fetchMonthlySalaries();
    });
  }

  @override
  void dispose() {
    _basicController.dispose();
    _transportController.dispose();
    _bonusController.dispose();
    super.dispose();
  }

  double _parseAmount(String raw) {
    return double.tryParse(raw.trim()) ?? 0;
  }

  Future<void> _saveSalary() async {
    final auth = context.read<AuthProvider>();
    final salaryProvider = context.read<SalaryProvider>();

    if (!auth.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admin can manage salaries')),
      );
      return;
    }

    if (_selectedUserId == null || _selectedUserId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a user')),
      );
      return;
    }

    final basic = _parseAmount(_basicController.text);
    final transport = _parseAmount(_transportController.text);
    final bonus = _parseAmount(_bonusController.text);

    if (basic < 0 || transport < 0 || bonus < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amounts cannot be negative')),
      );
      return;
    }

    final ok = await salaryProvider.saveMonthlySalary(
      userId: _selectedUserId!,
      year: salaryProvider.selectedYear,
      month: salaryProvider.selectedMonth,
      basicSalary: basic,
      transportAllowance: transport,
      bonus: bonus,
    );

    if (!mounted) {
      return;
    }

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monthly salary saved')),
      );
      _basicController.text = '0';
      _transportController.text = '0';
      _bonusController.text = '0';
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(salaryProvider.error ?? 'Failed to save salary')),
    );
  }

  InputDecoration _controlDecoration(String labelText) {
    return InputDecoration(
      labelText: labelText,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_controlRadius),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_controlRadius),
        borderSide: _enabledBorderSide,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_controlRadius),
        borderSide: _focusedBorderSide,
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _iconActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    Color color = const Color(0xFF1976D2),
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: _actionButtonSize,
        width: _actionButtonSize,
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(_controlRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(_controlRadius),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_controlRadius),
                border: const Border.fromBorderSide(_enabledBorderSide),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _salaryRowCard(MonthlySalary item) {
    final firstChar = item.username.isNotEmpty ? item.username[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              child: Text(
                firstChar,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Role: ${item.role.toUpperCase()}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                  Text(
                    'Basic Salary: ${item.basicSalary.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                  Text(
                    'Transport Allowance: ${item.transportAllowance.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                  Text(
                    'Bonus: ${item.bonus.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                  Text(
                    'Total Salary: ${item.totalSalary.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAdmin) {
      return const Center(
        child: Text('Only admin can view salary details'),
      );
    }

    final users = auth.users
        .where((u) => u.isActive)
        .toList()
      ..sort((a, b) => a.username.compareTo(b.username));

    return Consumer<SalaryProvider>(
      builder: (context, salaryProvider, _) {
        final now = DateTime.now();
        final years = List<int>.generate(6, (i) => now.year - 2 + i);
        final normalizedQuery = _searchQuery.trim().toLowerCase();
        final filteredSalaries = normalizedQuery.isEmpty
            ? salaryProvider.salaries
            : salaryProvider.salaries.where((item) {
                return item.username.toLowerCase().contains(normalizedQuery) ||
                    item.role.toLowerCase().contains(normalizedQuery) ||
                    item.salaryMonth.toString().contains(normalizedQuery) ||
                    item.salaryYear.toString().contains(normalizedQuery);
              }).toList();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        height: _controlHeight,
                        child: DropdownButtonFormField<int>(
                          value: salaryProvider.selectedMonth,
                          decoration: _controlDecoration('Month'),
                          items: List.generate(12, (i) => i + 1)
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(m.toString().padLeft(2, '0')),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            salaryProvider.fetchMonthlySalaries(
                              month: value,
                              year: salaryProvider.selectedYear,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 110,
                        height: _controlHeight,
                        child: DropdownButtonFormField<int>(
                          value: salaryProvider.selectedYear,
                          decoration: _controlDecoration('Year'),
                          items: years
                              .map(
                                (y) => DropdownMenuItem(
                                  value: y,
                                  child: Text(y.toString()),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            salaryProvider.fetchMonthlySalaries(
                              month: salaryProvider.selectedMonth,
                              year: value,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 280,
                        height: _controlHeight,
                        child: DropdownButtonFormField<String>(
                          value: _selectedUserId,
                          isExpanded: true,
                          decoration: _controlDecoration('Select Person'),
                          items: users
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u.id,
                                  child: Text('${u.username} (${u.role.name})'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedUserId = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 170,
                        height: _controlHeight,
                        child: TextField(
                          controller: _basicController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _controlDecoration('Basic Salary'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 170,
                        height: _controlHeight,
                        child: TextField(
                          controller: _transportController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _controlDecoration('Transport'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 140,
                        height: _controlHeight,
                        child: TextField(
                          controller: _bonusController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _controlDecoration('Bonus'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _iconActionButton(
                        icon: Icons.refresh,
                        tooltip: 'Refresh',
                        onTap: salaryProvider.isLoading
                            ? null
                            : () => salaryProvider.fetchMonthlySalaries(
                                  month: salaryProvider.selectedMonth,
                                  year: salaryProvider.selectedYear,
                                ),
                      ),
                      const SizedBox(width: 8),
                      _iconActionButton(
                        icon: Icons.save,
                        tooltip: 'Save Monthly Salary',
                        onTap: salaryProvider.isLoading ? null : _saveSalary,
                        color: const Color(0xFF2E7D32),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search salaries...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: salaryProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (salaryProvider.error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                salaryProvider.error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          Expanded(
                            child: filteredSalaries.isEmpty
                                ? const Center(child: Text('No salary records found'))
                                : ListView.builder(
                                    itemCount: filteredSalaries.length,
                                    itemBuilder: (context, index) {
                                      final item = filteredSalaries[index];
                                      return _salaryRowCard(item);
                                    },
                                  ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
