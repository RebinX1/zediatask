import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zediatask/models/models.dart';
import 'package:zediatask/providers/providers.dart';
import 'package:zediatask/screens/admin/constants_management_screen.dart';
import 'package:zediatask/screens/admin/task_management_screen.dart';
import 'package:zediatask/screens/admin/user_management_screen.dart';
import 'package:zediatask/utils/app_theme.dart';

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRoleAsync = ref.watch(userRoleProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
      ),
      body: userRoleAsync.when(
        data: (role) {
          if (role != UserRole.admin) {
            return const Center(
              child: Text('You do not have permission to access this page.'),
            );
          }
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionTitle(context, 'User Management'),
              AdminMenuCard(
                title: 'Manage Users',
                description: 'View and manage user accounts, roles, and permissions',
                icon: Icons.people,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UserManagementScreen()),
                  );
                },
              ),
              
              const SizedBox(height: 24),
              _buildSectionTitle(context, 'Task Management'),
              AdminMenuCard(
                title: 'Manage Tasks',
                description: 'Create, edit, and delete tasks for all employees',
                icon: Icons.task,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TaskManagementScreen()),
                  );
                },
              ),
              AdminMenuCard(
                title: 'Task Templates',
                description: 'Create and manage reusable task templates',
                icon: Icons.library_books,
                onTap: () {
                  _showFeatureNotImplemented(context);
                },
              ),
              AdminMenuCard(
                title: 'Tags Management',
                description: 'Create and organize tags for task categorization',
                icon: Icons.sell,
                onTap: () {
                  _showFeatureNotImplemented(context);
                },
              ),
              
              const SizedBox(height: 24),
              _buildSectionTitle(context, 'System Settings'),
              AdminMenuCard(
                title: 'Points System',
                description: 'Configure point values for different task actions',
                icon: Icons.stars,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ConstantsManagementScreen()),
                  );
                },
              ),
              AdminMenuCard(
                title: 'Notification Settings',
                description: 'Configure system-wide notification preferences',
                icon: Icons.notifications,
                onTap: () {
                  _showFeatureNotImplemented(context);
                },
              ),
              AdminMenuCard(
                title: 'Backup & Restore',
                description: 'Manage system backups and restore functionality',
                icon: Icons.settings_backup_restore,
                onTap: () {
                  _showFeatureNotImplemented(context);
                },
              ),
              
              const SizedBox(height: 24),
              _buildSectionTitle(context, 'Reports'),
              AdminMenuCard(
                title: 'Performance Reports',
                description: 'Generate and view detailed employee performance reports',
                icon: Icons.bar_chart,
                onTap: () {
                  _showFeatureNotImplemented(context);
                },
              ),
              AdminMenuCard(
                title: 'Task Analytics',
                description: 'View task completion statistics and trends',
                icon: Icons.analytics,
                onTap: () {
                  _showFeatureNotImplemented(context);
                },
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  void _showFeatureNotImplemented(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This feature is not implemented yet'),
        backgroundColor: AppTheme.secondaryColor,
      ),
    );
  }
}

// A dedicated widget for admin menu cards
class AdminMenuCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const AdminMenuCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondaryColor,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 