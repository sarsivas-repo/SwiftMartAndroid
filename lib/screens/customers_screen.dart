import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/customer_provider.dart';
import '../utils/app_utils.dart';
import '../widgets/product_widgets.dart';
import '../utils/constants.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({Key? key}) : super(key: key);

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<CustomerProvider>().fetchCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search field
            TextField(
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                context.read<CustomerProvider>().setSearchQuery(value);
              },
            ),
            const SizedBox(height: 16),

            // Customers list
            Expanded(
              child: Consumer<CustomerProvider>(
                builder: (context, customerProvider, _) {
                  if (customerProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (customerProvider.error != null) {
                    return Center(child: Text(customerProvider.error!));
                  }

                  if (customerProvider.filteredCustomers.isEmpty) {
                    return const Center(child: Text('No customers found'));
                  }

                  return ListView.builder(
                    itemCount: customerProvider.filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = customerProvider.filteredCustomers[index];
                      return CustomerTile(
                        customer: customer,
                        onTap: () => _showCustomerDetails(context, customer),
                        onEdit: () => _showEditCustomerDialog(context, customer),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCustomerDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCustomerDetails(BuildContext context, Customer customer) async {
    await context.read<CustomerProvider>().selectCustomer(customer.id);
    if (!context.mounted) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(customer.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: ${customer.email}'),
              Text('Phone: ${customer.phone}'),
              Text('Address: ${customer.address}'),
              Text('Total Spent: ${AppUtils.formatCurrency(customer.totalSpent)}'),
              Text('Bills: ${customer.billCount}'),
              const Divider(),
              const Text('Purchase History:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Consumer<CustomerProvider>(
                builder: (context, customerProvider, _) {
                  if (customerProvider.isLoading) {
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (customerProvider.error != null) {
                    return Text(customerProvider.error!);
                  }

                  if (customerProvider.customerHistory.isEmpty) {
                    return const Text('No purchase history');
                  }

                  return SizedBox(
                    height: 200,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: customerProvider.customerHistory.length,
                      itemBuilder: (context, index) {
                        final bill = customerProvider.customerHistory[index];
                        return Text(
                          '${bill.createdAt.toString().split('.')[0]} - ${AppUtils.formatCurrency(bill.total)}',
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showEditCustomerDialog(this.context, customer);
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Register New Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              Consumer<CustomerProvider>(
                builder: (_, provider, __) => provider.error == null
                    ? const SizedBox.shrink()
                    : Text(provider.error!, style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await context.read<CustomerProvider>().registerCustomer(
                    nameController.text,
                    emailController.text,
                    phoneController.text,
                    addressController.text,
                  );

              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Customer registered successfully')),
                );
              }
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }

  void _showEditCustomerDialog(BuildContext context, Customer customer) {
    final nameController = TextEditingController(text: customer.name);
    final emailController = TextEditingController(text: customer.email);
    final phoneController = TextEditingController(text: customer.phone);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await context.read<CustomerProvider>().updateCustomer(
                    customer.id,
                    nameController.text,
                    emailController.text,
                    phoneController.text,
                  );

              if (!mounted) {
                return;
              }

              if (success) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Customer updated successfully')),
                );
              } else {
                final error = context.read<CustomerProvider>().error ?? 'Failed to update customer';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error)),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
