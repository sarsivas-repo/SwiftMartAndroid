import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _searchQuery = '';

  Future<void> _toggleUserStatus(BuildContext context, User user) async {
    final authProvider = context.read<AuthProvider>();
    final willActivate = !user.isActive;

    if (!willActivate && authProvider.user?.id == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot deactivate your own account')),
      );
      return;
    }

    final success = await authProvider.updateUser(
      userId: user.id,
      username: user.username,
      email: user.email,
      mobile: user.mobile,
      roles: user.roles,
      isActive: willActivate,
    );

    if (!context.mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.username} ${willActivate ? 'activated' : 'deactivated'} successfully')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(authProvider.error ?? 'Failed to update user status')),
    );
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<AuthProvider>().fetchUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.isLoading && authProvider.users.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (authProvider.error != null && authProvider.users.isEmpty) {
            return Center(
              child: Text(authProvider.error!),
            );
          }

          if (authProvider.users.isEmpty) {
            return const Center(
              child: Text('No users found'),
            );
          }

          final normalizedQuery = _searchQuery.trim().toLowerCase();
          final filteredUsers = normalizedQuery.isEmpty
              ? authProvider.users
              : authProvider.users.where((user) {
                  return user.username.toLowerCase().contains(normalizedQuery) ||
                      user.email.toLowerCase().contains(normalizedQuery) ||
                      user.mobile.toLowerCase().contains(normalizedQuery) ||
                      user.roleSummary.toLowerCase().contains(normalizedQuery);
                }).toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search users...',
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
                const SizedBox(height: 16),
                Expanded(
                  child: filteredUsers.isEmpty
                      ? const Center(child: Text('No users found'))
                      : RefreshIndicator(
                          onRefresh: authProvider.fetchUsers,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              return _UserRowCard(
                                user: user,
                                onToggleStatus: () => _toggleUserStatus(context, user),
                                onAction: (value) {
                                  if (value == 'edit') {
                                    _showEditUserDialog(context, user);
                                  } else if (value == 'reset_password') {
                                    _showResetPasswordDialog(context, user);
                                  } else if (value == 'delete') {
                                    _showDeleteUserDialog(context, user);
                                  }
                                },
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateUserDialog(context),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _showCreateUserDialog(BuildContext context) {
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    UserRole selectedRole = UserRole.cashier;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create User'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Role',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<UserRole>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: UserRole.values
                        .map(
                          (item) => DropdownMenuItem<UserRole>(
                            value: item,
                            child: Text(item.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() {
                        selectedRole = value;
                      });
                    },
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await context.read<AuthProvider>().createUser(
                    username: usernameController.text.trim(),
                    email: emailController.text.trim(),
                    password: passwordController.text,
                    roles: [selectedRole],
                  );

              if (!context.mounted) {
                return;
              }

              if (success) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User created successfully')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.read<AuthProvider>().error ?? 'Failed to create user')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, User user) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Password: ${user.username}'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New Temporary Password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await context.read<AuthProvider>().adminResetUserPassword(
                    userId: user.id,
                    newPassword: passwordController.text,
                  );

              if (!context.mounted) {
                return;
              }

              if (success) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password reset completed. User must change password after login.'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.read<AuthProvider>().error ?? 'Failed to reset password')),
                );
              }
            },
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, User user) {
    final emailController = TextEditingController(text: user.email);
    final mobileController = TextEditingController(text: user.mobile);
    UserRole selectedRole = user.role;
    bool isActive = user.isActive;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit User: ${user.username}'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: mobileController,
                    decoration: const InputDecoration(labelText: 'Mobile'),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: isActive,
                    title: const Text('Active'),
                    onChanged: (value) {
                      setDialogState(() {
                        isActive = value ?? true;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Role',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<UserRole>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: UserRole.values
                        .map((item) => DropdownMenuItem<UserRole>(
                              value: item,
                              child: Text(item.name.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedRole = value);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await context.read<AuthProvider>().updateUser(
                    userId: user.id,
                    username: user.username,
                    email: emailController.text.trim(),
                    mobile: mobileController.text.trim(),
                    roles: [selectedRole],
                    isActive: isActive,
                  );

              if (!context.mounted) {
                return;
              }

              if (success) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User updated successfully')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.read<AuthProvider>().error ?? 'Failed to update user')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteUserDialog(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this user? All user details will be removed:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Username', user.username),
            _buildDetailRow('Email', user.email),
            _buildDetailRow('Mobile', user.mobile.isEmpty ? 'N/A' : user.mobile),
            _buildDetailRow('Roles', user.roleSummary),
            _buildDetailRow('Status', user.isActive ? 'Active' : 'Inactive'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'This action cannot be undone',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final success = await context.read<AuthProvider>().deleteUser(
                    userId: user.id,
                    hardDelete: true,
                  );

              if (!context.mounted) {
                return;
              }

              if (success) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User deleted successfully')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.read<AuthProvider>().error ?? 'Failed to delete user')),
                );
              }
            },
            child: const Text('Delete User', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(value, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _UserRowCard extends StatelessWidget {
  final User user;
  final VoidCallback onToggleStatus;
  final ValueChanged<String> onAction;

  const _UserRowCard({
    required this.user,
    required this.onToggleStatus,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final firstChar = user.username.isNotEmpty ? user.username[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
              child: Text(
                user.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.email_outlined, size: 12),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 12),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      user.mobile.isNotEmpty ? user.mobile : 'N/A',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined, size: 12),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      user.roleSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: onToggleStatus,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: user.isActive ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      user.isActive ? 'Active' : 'Inactive',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: user.isActive ? Colors.green.shade700 : Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (user.mustChangePassword) ...[
              const SizedBox(width: 8),
              const Tooltip(
                message: 'Password reset pending',
                child: Icon(Icons.vpn_key_outlined, size: 14, color: Colors.orange),
              ),
            ],
            PopupMenuButton<String>(
              onSelected: onAction,
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'reset_password',
                  child: Row(
                    children: [
                      Icon(Icons.vpn_key, size: 18),
                      SizedBox(width: 8),
                      Text('Reset Password'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
