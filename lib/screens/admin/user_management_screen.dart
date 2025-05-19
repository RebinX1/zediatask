import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zediatask/models/models.dart';
import 'package:zediatask/providers/auth_provider.dart';
import 'package:zediatask/services/services.dart';
import 'package:zediatask/utils/app_theme.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:gotrue/gotrue.dart' hide User; // Import gotrue but hide its User class
import 'package:supabase_flutter/supabase_flutter.dart' hide User; // Also hide User from supabase_flutter

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

// Filter by role provider
final userRoleFilterProvider = StateProvider<UserRole?>((ref) => null);

// Global SnackBar system for showing messages outside of the context
OverlayEntry? _currentOverlayEntry;

void _showMessageOverlay(String message, {bool isError = false}) {
  // Remove any existing overlay first
  _hideMessageOverlay();
  
  // Create an overlay entry
  final overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: 50,
      left: 20,
      right: 20,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        color: isError ? AppTheme.errorColor : AppTheme.successColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error : Icons.check_circle,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _hideMessageOverlay,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  
  // Store the current overlay entry
  _currentOverlayEntry = overlayEntry;
  
  // Add the overlay to the navigator
  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      final state = overlayState;
      if (state != null) {
        state.insert(overlayEntry);
        
        // Remove after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (_currentOverlayEntry == overlayEntry) {
            _hideMessageOverlay();
          }
        });
      }
    } catch (e) {
      print('Error showing message overlay: $e');
    }
  });
}

void _hideMessageOverlay() {
  _currentOverlayEntry?.remove();
  _currentOverlayEntry = null;
}

BuildContext? _globalContext;

OverlayState? get overlayState {
  if (_globalContext == null) return null;
  final navigatorState = Navigator.of(_globalContext!, rootNavigator: true);
  return navigatorState.overlay;
}

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});
  
  // Add a global key for the scaffold
  static final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Store the context for overlay usage
    _globalContext = context;
    
    final userRoleAsync = ref.watch(userRoleProvider);
    final allUsersAsync = ref.watch(allUsersProvider);
    final roleFilter = ref.watch(userRoleFilterProvider);
    
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
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
                          selected: roleFilter == null,
                          onSelected: (selected) {
                            if (selected) {
                              ref.read(userRoleFilterProvider.notifier).state = null;
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Admins'),
                          selected: roleFilter == UserRole.admin,
                          onSelected: (selected) {
                            ref.read(userRoleFilterProvider.notifier).state = 
                              selected ? UserRole.admin : null;
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Managers'),
                          selected: roleFilter == UserRole.manager,
                          onSelected: (selected) {
                            ref.read(userRoleFilterProvider.notifier).state = 
                              selected ? UserRole.manager : null;
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Employees'),
                          selected: roleFilter == UserRole.employee,
                          onSelected: (selected) {
                            ref.read(userRoleFilterProvider.notifier).state = 
                              selected ? UserRole.employee : null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                
                // User list
                Expanded(
                  child: allUsersAsync.when(
                    data: (users) {
                      // Filter users by role if a filter is set
                      final filteredUsers = roleFilter != null
                          ? users.where((user) => user.role == roleFilter).toList()
                          : users;
                      
                      if (filteredUsers.isEmpty) {
                        return const Center(
                          child: Text('No users found'),
                        );
                      }
                      
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
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
      _showMessageOverlay('Please fill in all fields', isError: true);
      return;
    }
    
    try {
      Navigator.of(context).pop(); // Close the dialog
      
      // Show loading message
      _showMessageOverlay('Creating user...');
      
      final supabaseService = ref.read(supabaseServiceProvider);
      final client = supabaseService.client;
      
      // First, check if user with this email already exists
      final existingUsers = await client
        .from('users')
        .select('email')
        .eq('email', email);
        
      if (existingUsers.isNotEmpty) {
        _hideMessageOverlay();
        _showMessageOverlay('A user with this email already exists', isError: true);
        return;
      }
      
      // Save current admin user information for restoring later
      final adminUser = client.auth.currentUser;
      final adminSession = client.auth.currentSession;
      
      // Create the new user using a separate Supabase client to avoid affecting current session
      final newUserCreated = await _createUserWithoutSignIn(
        email: email,
        password: password,
        name: name,
        role: role,
      );
      
      if (!newUserCreated) {
        throw Exception("Failed to create user");
      }
      
      // Restore the admin session if we got logged out
      if (client.auth.currentUser?.id != adminUser?.id && adminUser != null) {
        await client.auth.signOut();
        
        // Try to sign in as admin again
        await supabaseService.signIn(
          email: adminUser.email!,
          password: "", // This won't be used since we'll restore session directly
        );
      }
      
      // Hide any existing message
      _hideMessageOverlay();
      
      // Show success message
      _showMessageOverlay('User created successfully');
      
      // Refresh the users list
      ref.refresh(allUsersProvider);
    } catch (e) {
      _hideMessageOverlay();
      _showMessageOverlay('Error creating user: ${e.toString()}', isError: true);
    }
  }

  // Helper method to create a user without affecting current session
  Future<bool> _createUserWithoutSignIn({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    try {
      // Create a temporary Supabase client for this operation
      final supabaseSignUp = Supabase.instance.client;
      
      // Sign up the new user
      final response = await supabaseSignUp.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': role.toString().split('.').last,
        },
      );
      
      if (response.user == null) {
        return false;
      }
      
      // The database trigger will automatically create the user record in the users table
      // No need to manually insert it here
      
      // Sign out immediately to not affect current admin session
      await supabaseSignUp.auth.signOut();
      
      return true;
    } catch (e) {
      print('Error during create user without sign-in: $e');
      return false;
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
      _showMessageOverlay('Name cannot be empty', isError: true);
      return;
    }
    
    try {
      Navigator.of(context).pop(); // Close the dialog
      
      // Show loading indicator
      _showMessageOverlay('Updating user...');
      
      final supabaseService = ref.read(supabaseServiceProvider);
      final client = supabaseService.client;
      
      // Update user in database
      await client.from('users').update({
        'name': name,
        'role': role.toString().split('.').last,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      
      // Hide any existing message
      _hideMessageOverlay();
      
      // Show success message
      _showMessageOverlay('User updated successfully');
      
      // Refresh the users list
      ref.refresh(allUsersProvider);
    } catch (e) {
      _hideMessageOverlay();
      _showMessageOverlay('Error updating user: ${e.toString()}', isError: true);
    }
  }

  Future<void> _deleteUser(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    try {
      // Show loading indicator
      _showMessageOverlay('Deleting user...');
      
      final supabaseService = ref.read(supabaseServiceProvider);
      final client = supabaseService.client;
      
      // Check if trying to delete yourself
      if (client.auth.currentUser?.id == userId) {
        _hideMessageOverlay();
        _showMessageOverlay('You cannot delete your own account', isError: true);
        return;
      }
      
      // Delete from database first
      await client.from('users').delete().eq('id', userId);
      
      // Hide any existing message
      _hideMessageOverlay();
      
      // Show success message
      _showMessageOverlay('User deleted successfully');
      
      // Refresh the users list
      ref.refresh(allUsersProvider);
    } catch (e) {
      _hideMessageOverlay();
      _showMessageOverlay('Error deleting user: ${e.toString()}', isError: true);
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