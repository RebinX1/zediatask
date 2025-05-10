import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zediatask/models/models.dart';
import 'package:zediatask/providers/providers.dart';
import 'package:zediatask/screens/auth/login_screen.dart';
import 'package:zediatask/screens/admin/admin_panel_screen.dart';
import 'package:zediatask/utils/app_theme.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDetailsAsync = ref.watch(userDetailsProvider);
    final userRoleAsync = ref.watch(userRoleProvider);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: userDetailsAsync.when(
        data: (userDetails) {
          if (userDetails == null) {
            return const Center(
              child: Text('No user data available'),
            );
          }
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(context, userDetails, ref),
              const SizedBox(height: 24),
              
              // Statistics
              if (userDetails['role'] == 'employee')
                _buildEmployeeStats(context, userDetails),
              
              const SizedBox(height: 24),
              
              // Settings & actions
              Text(
                'Settings',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              
              // Settings menu
              _buildSettingsMenu(context, ref, userRoleAsync),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, Map<String, dynamic> userDetails, WidgetRef ref) {
    return Column(
      children: [
        // User avatar
        CircleAvatar(
          radius: 50,
          backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
          child: Text(
            _getInitials(userDetails['name'] ?? ''),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // User name
        Text(
          userDetails['name'] ?? 'User',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        
        // User email
        Text(
          userDetails['email'] ?? '',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        
        // User role
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: _getRoleColor(userDetails['role']).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _getRoleText(userDetails['role']),
            style: TextStyle(
              color: _getRoleColor(userDetails['role']),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeStats(BuildContext context, Map<String, dynamic> userDetails) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard(
              context,
              title: 'Points',
              value: '${userDetails['total_points'] ?? 0}',
              icon: Icons.star,
              color: const Color(0xFFFFD700), // Gold
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              context,
              title: 'Tasks Completed',
              value: '${userDetails['tasks_completed'] ?? 0}',
              icon: Icons.task_alt,
              color: AppTheme.completedStatusColor,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard(
              context,
              title: 'Avg. Completion Time',
              value: _formatAvgTime(userDetails['avg_completion_time']),
              icon: Icons.timer,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              context,
              title: 'Current Rank',
              value: '#${userDetails['rank'] ?? '-'}',
              icon: Icons.leaderboard,
              color: AppTheme.secondaryColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsMenu(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<UserRole?> userRoleAsync,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Notifications
          _buildSettingsItem(
            context,
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Configure notification settings',
            onTap: () {
              // Navigate to notifications settings
            },
          ),
          const Divider(height: 1),
          
          // App Theme
          _buildSettingsItem(
            context,
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'App theme and display settings',
            onTap: () {
              // Navigate to appearance settings
            },
          ),
          const Divider(height: 1),
          
          // Admin Panel - Only for admins
          userRoleAsync.maybeWhen(
            data: (role) {
              if (role == UserRole.admin) {
                return Column(
                  children: [
                    _buildSettingsItem(
                      context,
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Admin Panel',
                      subtitle: 'Manage users and app settings',
                      onTap: () {
                        // Navigate to admin panel
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminPanelScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),
          
          // Help & Support
          _buildSettingsItem(
            context,
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Get assistance and contact support',
            onTap: () {
              // Navigate to help & support
            },
          ),
          const Divider(height: 1),
          
          // About
          _buildSettingsItem(
            context,
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'App information and version',
            onTap: () {
              // Navigate to about screen
            },
          ),
          const Divider(height: 1),
          
          // Logout
          _buildSettingsItem(
            context,
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out from your account',
            onTap: () async {
              final navigator = Navigator.of(context);
              await ref.read(supabaseServiceProvider).signOut();
              
              // Clear the logged in user state
              ref.read(loggedInUserProvider.notifier).state = null;
              
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            iconColor: AppTheme.errorColor,
            titleColor: AppTheme.errorColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? AppTheme.primaryColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: titleColor ?? AppTheme.textPrimaryColor,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppTheme.textSecondaryColor,
      ),
      onTap: onTap,
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '';
    
    final nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}';
    } else if (nameParts.length == 1) {
      return nameParts[0][0];
    }
    
    return '';
  }

  String _getRoleText(String? role) {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'manager':
        return 'Manager';
      case 'employee':
        return 'Employee';
      default:
        return 'User';
    }
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'manager':
        return AppTheme.secondaryColor;
      case 'employee':
        return AppTheme.primaryColor;
      default:
        return AppTheme.textSecondaryColor;
    }
  }

  String _formatAvgTime(dynamic avgTime) {
    if (avgTime == null) return '-';
    
    final double avgHours = avgTime.toDouble();
    if (avgHours < 1) {
      return '${(avgHours * 60).round()} min';
    } else if (avgHours < 24) {
      return '${avgHours.toStringAsFixed(1)} hr';
    } else {
      return '${(avgHours / 24).toStringAsFixed(1)} days';
    }
  }
} 