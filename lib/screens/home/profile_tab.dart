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
    
    return userDetailsAsync.when(
      data: (userDetails) {
        if (userDetails == null) {
          return const Center(
            child: Text('No user data available'),
          );
        }
        
        return CustomScrollView(
          slivers: [
            // App Bar with profile info
            SliverAppBar(
              expandedHeight: 200,
              backgroundColor: AppTheme.primaryColor,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.backgroundColor, // Very dark blue
                        AppTheme.primaryColor,   // Dark teal blue
                        AppTheme.secondaryColor, // Medium teal blue
                      ],
                    ),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/triangle_pattern.png'),
                      fit: BoxFit.cover,
                      opacity: 0.15, // Make the pattern subtle
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.white,
                        child: Text(
                          _getInitials(userDetails['name'] ?? ''),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userDetails['name'] ?? 'User',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userDetails['email'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Role badge
            SliverToBoxAdapter(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor(userDetails['role']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getRoleColor(userDetails['role']).withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getRoleText(userDetails['role']),
                    style: TextStyle(
                      color: _getRoleColor(userDetails['role']),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            
            // Statistics section (only for employees)
            if (userDetails['role'] == 'employee')
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: _buildEmployeeStats(context, userDetails),
                ),
              ),
            
            // Settings section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 16),
                      child: Text(
                        'Account Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    ),
                    _buildSettingsMenu(context, ref, userRoleAsync),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
        child: Text('Error: $error'),
      ),
    );
  }

  Widget _buildEmployeeStats(BuildContext context, Map<String, dynamic> userDetails) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 16),
          child: Text(
            'Performance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
        ),
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
              title: 'Avg.Completion Time',
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
                      subtitle: 'Manage users and organization settings',
                      onTap: () {
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
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: titleColor ?? AppTheme.textPrimaryColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 13,
          color: AppTheme.textSecondaryColor,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppTheme.textSecondaryColor,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '';
    
    final nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (nameParts.length == 1 && nameParts[0].isNotEmpty) {
      return nameParts[0][0].toUpperCase();
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