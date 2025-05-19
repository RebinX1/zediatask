import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zediatask/models/models.dart';
import 'package:zediatask/providers/auth_provider.dart';
import 'package:zediatask/services/services.dart';
import 'package:zediatask/utils/app_theme.dart';

// This provider will handle fetching all users from the database
final allUsersProvider = FutureProvider<List<User>>((ref) async {
  final supabaseService = ref.read(supabaseServiceProvider);
  final client = supabaseService.client;
  
  try {
    final data = await client.from('users').select().order('name');
    return data.map((json) => User.fromJson(json)).toList();
  } catch (e) {
    print('Error fetching users: $e');
    return [];
  }
});

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRoleAsync = ref.watch(userRoleProvider);
    final allUsersAsync = ref.watch(allUsersProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
      ),
      body: userRoleAsync.when(
        data: (role) {
          if (role != UserRole.admin) {
            return const Center(
              child: Text('You do not have permission to access this page.'),
            );
          }
          
          return Column(
            children: [
              // Add User Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () => _showAddUserDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Add New User'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ),
              
              // User Filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: true,
                        onSelected: (selected) {},
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Admins'),
                        selected: false,
                        onSelected: (selected) {},
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Managers'),
                        selected: false,
                        onSelected: (selected) {},
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Employees'),
                        selected: false,
                        onSelected: (selected) {},
                      ),
                    ],
                  ),
                ),
              ),
              
              // User list
              Expanded(
                child: allUsersAsync.when(
                  data: (users) {
                    if (users.isEmpty) {
                      return const Center(
                        child: Text('No users found'),
                      );
                    }
                    
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return _buildUserCard(context, ref, user);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stack) => Center(
                    child: Text('Error: $error'),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (_, __) => const Center(
          child: Text('Error loading user information'),
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, WidgetRef ref, User user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // User avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: _getRoleColor(user.role).withOpacity(0.2),
              child: Text(
                _getInitials(user.name),
                style: TextStyle(
                  color: _getRoleColor(user.role),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // User details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getRoleColor(user.role).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getRoleText(user.role),
                      style: TextStyle(
                        color: _getRoleColor(user.role),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Action buttons
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  color: AppTheme.primaryColor,
                  onPressed: () => _showEditUserDialog(context, ref, user),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  color: AppTheme.errorColor,
                  onPressed: () => _showDeleteConfirmation(context, ref, user),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUserDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    UserRole selectedRole = UserRole.employee;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<UserRole>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.badge),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: UserRole.admin,
                      child: Text('Administrator'),
                    ),
                    DropdownMenuItem(
                      value: UserRole.manager,
                      child: Text('Manager'),
                    ),
                    DropdownMenuItem(
                      value: UserRole.employee,
                      child: Text('Employee'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedRole = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _addNewUser(
                  context, 
                  ref, 
                  nameController.text.trim(), 
                  emailController.text.trim(), 
                  passwordController.text, 
                  selectedRole,
                );
              },
              child: const Text('Create User'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, WidgetRef ref, User user) {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    UserRole selectedRole = user.role;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: false, // Email cannot be changed
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<UserRole>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.badge),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: UserRole.admin,
                      child: Text('Administrator'),
                    ),
                    DropdownMenuItem(
                      value: UserRole.manager,
                      child: Text('Manager'),
                    ),
                    DropdownMenuItem(
                      value: UserRole.employee,
                      child: Text('Employee'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedRole = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateUser(
                  context, 
                  ref, 
                  user.id,
                  nameController.text.trim(), 
                  selectedRole,
                );
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteUser(context, ref, user.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewUser(
    BuildContext context,
    WidgetRef ref,
    String name,
    String email,
    String password,
    UserRole role,
  ) async {
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    
    try {
      Navigator.of(context).pop(); // Close the dialog
      
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Creating user...'),
          duration: Duration(days: 1), // "Infinite" duration until we dismiss it
        ),
      );
      
      final supabaseService = ref.read(supabaseServiceProvider);
      await supabaseService.signUp(
        name: name,
        email: email,
        password: password,
        role: role,
      );
      
      // Dismiss the loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User created successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      
      // Refresh the users list
      ref.refresh(allUsersProvider);
    } catch (e) {
      // Dismiss the loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating user: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _updateUser(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String name,
    UserRole role,
  ) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    
    try {
      Navigator.of(context).pop(); // Close the dialog
      
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Updating user...'),
          duration: Duration(days: 1), // "Infinite" duration until we dismiss it
        ),
      );
      
      final supabaseService = ref.read(supabaseServiceProvider);
      final client = supabaseService.client;
      
      // Update user in database
      await client.from('users').update({
        'name': name,
        'role': role.toString().split('.').last,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      
      // Dismiss the loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User updated successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      
      // Refresh the users list
      ref.refresh(allUsersProvider);
    } catch (e) {
      // Dismiss the loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating user: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _deleteUser(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deleting user...'),
          duration: Duration(days: 1), // "Infinite" duration until we dismiss it
        ),
      );
      
      final supabaseService = ref.read(supabaseServiceProvider);
      final client = supabaseService.client;
      
      // In a real application, you would implement proper cascading deletion
      // of related records (tasks, comments, etc.)
      await client.from('users').delete().eq('id', userId);
      
      // Dismiss the loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User deleted successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      
      // Refresh the users list
      ref.refresh(allUsersProvider);
    } catch (e) {
      // Dismiss the loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting user: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '';
    
    final nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (nameParts.length == 1) {
      return nameParts[0][0].toUpperCase();
    }
    
    return '';
  }

  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.manager:
        return 'Manager';
      case UserRole.employee:
        return 'Employee';
      default:
        return 'User';
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.manager:
        return AppTheme.secondaryColor;
      case UserRole.employee:
        return AppTheme.primaryColor;
      default:
        return AppTheme.textSecondaryColor;
    }
  }
} 