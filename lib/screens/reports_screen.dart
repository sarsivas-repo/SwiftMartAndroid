import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/reports_provider.dart';
import '../providers/bill_provider.dart';
import '../utils/app_utils.dart';
import '../utils/constants.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;
  DateTime _selectedDate = DateTime.now();
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  double _manualInvestment = 0;
  double _manualProfitAdjustment = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      setState(() => _selectedTab = _tabController.index);
      _loadTabData();
    });
    _loadTabData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadTabData() async {
    final reportsProvider = context.read<ReportsProvider>();
    final billProvider = context.read<BillProvider>();

    if (_selectedTab == 0) {
      await reportsProvider.fetchDailySalesReport(_selectedDate);
    } else if (_selectedTab == 1) {
      await reportsProvider.fetchMonthlySalesReport(_selectedYear, _selectedMonth);
    } else if (_selectedTab == 2) {
      await billProvider.fetchBills();
    } else if (_selectedTab == 3) {
      await reportsProvider.fetchManualFinanceEntry(_selectedYear, _selectedMonth);
      if (!mounted) {
        return;
      }
      final entry = reportsProvider.manualFinanceEntry;
      setState(() {
        _manualInvestment = (entry?['manual_investment'] as num?)?.toDouble() ?? 0;
        _manualProfitAdjustment = (entry?['manual_profit_adjustment'] as num?)?.toDouble() ?? 0;
      });
      await reportsProvider.fetchProfitLossReport(_selectedYear, _selectedMonth);
    } else if (_selectedTab == 4) {
      await reportsProvider.fetchManualFinanceEntry(_selectedYear, _selectedMonth);
      if (!mounted) {
        return;
      }
      final entry = reportsProvider.manualFinanceEntry;
      setState(() {
        _manualInvestment = (entry?['manual_investment'] as num?)?.toDouble() ?? 0;
        _manualProfitAdjustment = (entry?['manual_profit_adjustment'] as num?)?.toDouble() ?? 0;
      });
      await reportsProvider.fetchInvestmentReturnReport(_selectedYear, _selectedMonth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: MediaQuery.sizeOf(context).width < 600,
          tabAlignment: MediaQuery.sizeOf(context).width < 600
              ? TabAlignment.start
              : null,
          tabs: const [
            Tab(text: 'Daily Status', icon: Icon(Icons.today)),
            Tab(text: 'Monthly Trends', icon: Icon(Icons.calendar_month)),
            Tab(text: 'All Bills', icon: Icon(Icons.receipt_long)),
            Tab(text: 'Profit/Loss', icon: Icon(Icons.show_chart)),
            Tab(text: 'Invest vs Return', icon: Icon(Icons.account_balance)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DailySalesTab(
            selectedDate: _selectedDate,
            onDateChanged: (date) {
              setState(() => _selectedDate = date);
              _loadTabData();
            },
          ),
          _MonthlySalesTab(
            selectedYear: _selectedYear,
            selectedMonth: _selectedMonth,
            onYearChanged: (year) {
              setState(() => _selectedYear = year);
              _loadTabData();
            },
            onMonthChanged: (month) {
              setState(() => _selectedMonth = month);
              _loadTabData();
            },
          ),
          const _AllBillsTab(),
          _ProfitLossTab(
            selectedYear: _selectedYear,
            selectedMonth: _selectedMonth,
            manualInvestment: _manualInvestment,
            manualProfitAdjustment: _manualProfitAdjustment,
            onYearChanged: (year) {
              setState(() => _selectedYear = year);
              _loadTabData();
            },
            onMonthChanged: (month) {
              setState(() => _selectedMonth = month);
              _loadTabData();
            },
            onManualInvestmentChanged: (value) {
              setState(() => _manualInvestment = value);
            },
            onManualProfitAdjustmentChanged: (value) {
              setState(() => _manualProfitAdjustment = value);
            },
            onSaveAndRefresh: () async {
              final reportsProvider = context.read<ReportsProvider>();
              final ok = await reportsProvider.saveManualFinanceEntry(
                year: _selectedYear,
                month: _selectedMonth,
                manualInvestment: _manualInvestment,
                manualProfitAdjustment: _manualProfitAdjustment,
              );
              if (!mounted) {
                return;
              }
              if (ok) {
                _loadTabData();
              }
            },
          ),
          _InvestmentReturnTab(
            selectedYear: _selectedYear,
            selectedMonth: _selectedMonth,
            manualInvestment: _manualInvestment,
            onYearChanged: (year) {
              setState(() => _selectedYear = year);
              _loadTabData();
            },
            onMonthChanged: (month) {
              setState(() => _selectedMonth = month);
              _loadTabData();
            },
            onManualInvestmentChanged: (value) {
              setState(() => _manualInvestment = value);
            },
            onSaveAndRefresh: () async {
              final reportsProvider = context.read<ReportsProvider>();
              final ok = await reportsProvider.saveManualFinanceEntry(
                year: _selectedYear,
                month: _selectedMonth,
                manualInvestment: _manualInvestment,
                manualProfitAdjustment: _manualProfitAdjustment,
              );
              if (!mounted) {
                return;
              }
              if (ok) {
                _loadTabData();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _DailySalesTab extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateChanged;

  const _DailySalesTab({
    required this.selectedDate,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date picker
            ListTile(
              title: const Text('Select Date'),
              trailing: Text(selectedDate.toString().split(' ')[0]),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  onDateChanged(date);
                }
              },
            ),
            const SizedBox(height: 24),

            // Stats cards
            Consumer<ReportsProvider>(
              builder: (context, reportsProvider, _) {
                final stats = reportsProvider.getDailyStats();
                return Column(
                  children: [
                    _StatsCard(
                      title: 'Total Sales',
                      value: AppUtils.formatCurrency((stats['totalSales'] as num?)?.toDouble() ?? 0),
                      icon: Icons.attach_money,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _StatsCard(
                      title: 'Bills Today',
                      value: '${stats['billCount'] ?? 0}',
                      icon: Icons.receipt,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _StatsCard(
                      title: 'Average Bill',
                      value: AppUtils.formatCurrency((stats['averageBill'] as num?)?.toDouble() ?? 0),
                      icon: Icons.calculate,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    _StatsCard(
                      title: 'Tax Collected',
                      value: AppUtils.formatCurrency((stats['taxCollected'] as num?)?.toDouble() ?? 0),
                      icon: Icons.attach_money,
                      color: Colors.red,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlySalesTab extends StatelessWidget {
  final int selectedYear;
  final int selectedMonth;
  final Function(int) onYearChanged;
  final Function(int) onMonthChanged;

  const _MonthlySalesTab({
    required this.selectedYear,
    required this.selectedMonth,
    required this.onYearChanged,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Year and Month selectors
            Row(
              children: [
                Expanded(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: selectedYear,
                    items: List.generate(5, (i) => DateTime.now().year - i).map((year) {
                      return DropdownMenuItem(value: year, child: Text(year.toString()));
                    }).toList(),
                    onChanged: (year) {
                      if (year != null) onYearChanged(year);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: selectedMonth,
                    items: List.generate(12, (i) => i + 1).map((month) {
                      final monthNames = [
                        'Jan',
                        'Feb',
                        'Mar',
                        'Apr',
                        'May',
                        'Jun',
                        'Jul',
                        'Aug',
                        'Sep',
                        'Oct',
                        'Nov',
                        'Dec'
                      ];
                      return DropdownMenuItem(
                        value: month,
                        child: Text(monthNames[month - 1]),
                      );
                    }).toList(),
                    onChanged: (month) {
                      if (month != null) onMonthChanged(month);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Monthly stats
            Consumer<ReportsProvider>(
              builder: (context, reportsProvider, _) {
                final stats = reportsProvider.getMonthlyStats();
                return Column(
                  children: [
                    _StatsCard(
                      title: 'Total Monthly Sales',
                      value: AppUtils.formatCurrency((stats['totalSales'] as num?)?.toDouble() ?? 0),
                      icon: Icons.attach_money,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _StatsCard(
                      title: 'Total Bills',
                      value: '${stats['billCount'] ?? 0}',
                      icon: Icons.receipt,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _StatsCard(
                      title: 'Average Bill',
                      value: AppUtils.formatCurrency((stats['averageBill'] as num?)?.toDouble() ?? 0),
                      icon: Icons.calculate,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    _StatsCard(
                      title: 'Total Tax',
                      value: AppUtils.formatCurrency((stats['taxCollected'] as num?)?.toDouble() ?? 0),
                      icon: Icons.receipt,
                      color: Colors.red,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // Monthly bills list
            Text(
              'Bills This Month',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            Consumer<ReportsProvider>(
              builder: (context, reportsProvider, _) {
                if (reportsProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (reportsProvider.monthlyReports.isEmpty) {
                  return const Center(child: Text('No bills this month'));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reportsProvider.monthlyReports.length,
                  itemBuilder: (context, index) {
                    final report = reportsProvider.monthlyReports[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('${report.date.day} ${_getMonthName(report.date.month)}'),
                        subtitle: Text('${report.billCount} bills • ${AppUtils.formatCurrency(report.totalSales)}'),
                        trailing: Text(
                          AppUtils.formatCurrency(report.totalSales),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return monthNames[month - 1];
  }
}

class _AllBillsTab extends StatelessWidget {
  const _AllBillsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<BillProvider>(
      builder: (context, billProvider, _) {
        if (billProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (billProvider.bills.isEmpty) {
          return const Center(child: Text('No bills found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: billProvider.bills.length,
          itemBuilder: (context, index) {
            final bill = billProvider.bills[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bill.status == BillStatus.completed ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt, color: Colors.white),
                ),
                title: Text('Bill #${bill.id}'),
                subtitle: Text(bill.createdAt.toString().split('.')[0]),
                trailing: Text(
                  AppUtils.formatCurrency(bill.total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () => _showBillDetails(context, bill),
              ),
            );
          },
        );
      },
    );
  }

  void _showBillDetails(BuildContext context, Bill bill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bill #${bill.id}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date: ${bill.createdAt}'),
              Text('Status: ${bill.status.toString().split('.').last}'),
              Text('Payment: ${bill.paymentMethod}'),
              const Divider(),
              Text('Subtotal: ${AppUtils.formatCurrency(bill.subtotal)}'),
              Text('Tax: ${AppUtils.formatCurrency(bill.taxAmount)}'),
              Text('Total: ${AppUtils.formatCurrency(bill.total)}'),
              const Divider(),
              const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...bill.items.map((item) => Text('${item.productName} x${item.quantity} = ${AppUtils.formatCurrency(item.subtotal)}')).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ProfitLossTab extends StatelessWidget {
  final int selectedYear;
  final int selectedMonth;
  final double manualInvestment;
  final double manualProfitAdjustment;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<double> onManualInvestmentChanged;
  final ValueChanged<double> onManualProfitAdjustmentChanged;
  final VoidCallback onSaveAndRefresh;

  const _ProfitLossTab({
    required this.selectedYear,
    required this.selectedMonth,
    required this.manualInvestment,
    required this.manualProfitAdjustment,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onManualInvestmentChanged,
    required this.onManualProfitAdjustmentChanged,
    required this.onSaveAndRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final monthNames = const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: selectedYear,
                    items: List.generate(6, (i) => DateTime.now().year - i)
                        .map((year) => DropdownMenuItem(value: year, child: Text(year.toString())))
                        .toList(),
                    onChanged: (year) {
                      if (year != null) {
                        onYearChanged(year);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: selectedMonth,
                    items: List.generate(12, (i) => i + 1)
                        .map((month) => DropdownMenuItem(value: month, child: Text(monthNames[month - 1])))
                        .toList(),
                    onChanged: (month) {
                      if (month != null) {
                        onMonthChanged(month);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('pl-mi-$selectedYear-$selectedMonth-$manualInvestment'),
                    initialValue: manualInvestment.toStringAsFixed(2),
                    decoration: const InputDecoration(
                      labelText: 'Manual Investment',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) => onManualInvestmentChanged(double.tryParse(value) ?? 0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('pl-mp-$selectedYear-$selectedMonth-$manualProfitAdjustment'),
                    initialValue: manualProfitAdjustment.toStringAsFixed(2),
                    decoration: const InputDecoration(
                      labelText: 'Manual Profit Adj',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) => onManualProfitAdjustmentChanged(double.tryParse(value) ?? 0),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: onSaveAndRefresh,
                  icon: const Icon(Icons.save),
                  label: const Text('Save & Apply'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<ReportsProvider>(
              builder: (context, reportsProvider, _) {
                if (reportsProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final report = reportsProvider.profitLossReport ?? <String, dynamic>{};
                final trend = reportsProvider.profitLossTrend;
                return Column(
                  children: [
                    _StatsCard(
                      title: 'Sales Revenue',
                      value: AppUtils.formatCurrency((report['sales_revenue'] as num?)?.toDouble() ?? 0),
                      icon: Icons.point_of_sale,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 10),
                    _StatsCard(
                      title: 'Total Investment (Stock + Salary + Manual)',
                      value: AppUtils.formatCurrency((report['total_investment'] as num?)?.toDouble() ?? 0),
                      icon: Icons.trending_down,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 10),
                    _StatsCard(
                      title: 'Net Profit/Loss',
                      value: AppUtils.formatCurrency((report['net_profit'] as num?)?.toDouble() ?? 0),
                      icon: Icons.show_chart,
                      color: ((report['net_profit'] as num?)?.toDouble() ?? 0) >= 0 ? Colors.green : Colors.red,
                    ),
                    const SizedBox(height: 10),
                    _StatsCard(
                      title: 'MoM Net Profit Change',
                      value: AppUtils.formatCurrency((report['net_profit_delta'] as num?)?.toDouble() ?? 0),
                      icon: Icons.compare_arrows,
                      color: ((report['net_profit_delta'] as num?)?.toDouble() ?? 0) >= 0 ? Colors.teal : Colors.red,
                    ),
                    const SizedBox(height: 16),
                    _TrendBars(
                      title: 'Yearly Profit Trend',
                      bars: trend,
                      valueKey: 'net_profit',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InvestmentReturnTab extends StatelessWidget {
  final int selectedYear;
  final int selectedMonth;
  final double manualInvestment;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<double> onManualInvestmentChanged;
  final VoidCallback onSaveAndRefresh;

  const _InvestmentReturnTab({
    required this.selectedYear,
    required this.selectedMonth,
    required this.manualInvestment,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onManualInvestmentChanged,
    required this.onSaveAndRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final monthNames = const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: selectedYear,
                    items: List.generate(6, (i) => DateTime.now().year - i)
                        .map((year) => DropdownMenuItem(value: year, child: Text(year.toString())))
                        .toList(),
                    onChanged: (year) {
                      if (year != null) {
                        onYearChanged(year);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: selectedMonth,
                    items: List.generate(12, (i) => i + 1)
                        .map((month) => DropdownMenuItem(value: month, child: Text(monthNames[month - 1])))
                        .toList(),
                    onChanged: (month) {
                      if (month != null) {
                        onMonthChanged(month);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('ir-mi-$selectedYear-$selectedMonth-$manualInvestment'),
                    initialValue: manualInvestment.toStringAsFixed(2),
                    decoration: const InputDecoration(
                      labelText: 'Manual Investment',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) => onManualInvestmentChanged(double.tryParse(value) ?? 0),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: onSaveAndRefresh,
                  icon: const Icon(Icons.save),
                  label: const Text('Save & Apply'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<ReportsProvider>(
              builder: (context, reportsProvider, _) {
                if (reportsProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final report = reportsProvider.investmentReturnReport ?? <String, dynamic>{};
                final trend = reportsProvider.investmentReturnTrend;
                return Column(
                  children: [
                    _StatsCard(
                      title: 'Investment (Salary + Stock + Manual)',
                      value: AppUtils.formatCurrency((report['total_investment'] as num?)?.toDouble() ?? 0),
                      icon: Icons.savings,
                      color: Colors.deepOrange,
                    ),
                    const SizedBox(height: 10),
                    _StatsCard(
                      title: 'Return (Sales)',
                      value: AppUtils.formatCurrency((report['sales_return'] as num?)?.toDouble() ?? 0),
                      icon: Icons.trending_up,
                      color: Colors.indigo,
                    ),
                    const SizedBox(height: 10),
                    _StatsCard(
                      title: 'Net Return',
                      value: AppUtils.formatCurrency((report['net_return'] as num?)?.toDouble() ?? 0),
                      icon: Icons.account_balance_wallet,
                      color: ((report['net_return'] as num?)?.toDouble() ?? 0) >= 0 ? Colors.green : Colors.red,
                    ),
                    const SizedBox(height: 10),
                    _StatsCard(
                      title: 'MoM Net Return Change',
                      value: AppUtils.formatCurrency((report['net_return_delta'] as num?)?.toDouble() ?? 0),
                      icon: Icons.swap_vert,
                      color: ((report['net_return_delta'] as num?)?.toDouble() ?? 0) >= 0 ? Colors.teal : Colors.red,
                    ),
                    const SizedBox(height: 16),
                    _TrendBars(
                      title: 'Yearly Return Trend',
                      bars: trend,
                      valueKey: 'sales_revenue',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendBars extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> bars;
  final String valueKey;

  const _TrendBars({
    required this.title,
    required this.bars,
    required this.valueKey,
  });

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxValue = bars.fold<double>(
      1,
      (max, row) {
        final value = (row[valueKey] as num?)?.toDouble().abs() ?? 0;
        return value > max ? value : max;
      },
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...bars.map((row) {
              final month = (row['month'] as num?)?.toInt() ?? 0;
              final value = (row[valueKey] as num?)?.toDouble() ?? 0;
              final ratio = (value.abs() / maxValue).clamp(0.0, 1.0);
              final positive = value >= 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 30, child: Text(month.toString().padLeft(2, '0'))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: ratio,
                          backgroundColor: Colors.grey.shade200,
                          color: positive ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: Text(
                        AppUtils.formatCurrency(value),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatsCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.7), color.withOpacity(0.9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
