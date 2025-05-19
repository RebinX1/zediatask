import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zediatask/constants/app_constants.dart';
import 'package:zediatask/providers/auth_provider.dart';
import 'package:zediatask/models/models.dart';
import 'package:zediatask/utils/app_theme.dart';

// This is a placeholder provider - in a real implementation, you would
// have a proper update mechanism connected to your database
final pointsSystemProvider = StateProvider<Map<String, int>>((ref) {
  return {
    'fastAcceptance': AppConstants.pointsFastAcceptance,
    'normalAcceptance': AppConstants.pointsNormalAcceptance,
    'completionBeforeDeadline': AppConstants.pointsCompletionBeforeDeadline,
    'completionOnTime': AppConstants.pointsCompletionOnTime,
    'basicCompletion': AppConstants.pointsBasicCompletion,
  };
});

class ConstantsManagementScreen extends ConsumerWidget {
  const ConstantsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRoleAsync = ref.watch(userRoleProvider);
    final pointsSystem = ref.watch(pointsSystemProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Constants'),
      ),
      body: userRoleAsync.when(
        data: (role) {
          if (role != UserRole.admin) {
            return const Center(
              child: Text('You do not have permission to access this page.'),
            );
          }
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(context, 'Points System'),
                const SizedBox(height: 8),
                Text(
                  'Configure point values for different task actions. These points contribute to employee scores.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                ),
                const SizedBox(height: 16),
                
                // Points System Settings
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildPointsSlider(
                          context,
                          ref,
                          title: 'Fast Acceptance',
                          description: 'Points awarded for accepting a task within an hour',
                          value: pointsSystem['fastAcceptance']!,
                          onChanged: (value) {
                            ref.read(pointsSystemProvider.notifier).state = {
                              ...pointsSystem,
                              'fastAcceptance': value,
                            };
                          },
                        ),
                        const Divider(),
                        _buildPointsSlider(
                          context,
                          ref,
                          title: 'Normal Acceptance',
                          description: 'Points awarded for accepting a task within a day',
                          value: pointsSystem['normalAcceptance']!,
                          onChanged: (value) {
                            ref.read(pointsSystemProvider.notifier).state = {
                              ...pointsSystem,
                              'normalAcceptance': value,
                            };
                          },
                        ),
                        const Divider(),
                        _buildPointsSlider(
                          context,
                          ref,
                          title: 'Early Completion',
                          description: 'Points awarded for completing a task before deadline',
                          value: pointsSystem['completionBeforeDeadline']!,
                          onChanged: (value) {
                            ref.read(pointsSystemProvider.notifier).state = {
                              ...pointsSystem,
                              'completionBeforeDeadline': value,
                            };
                          },
                          max: 20,
                        ),
                        const Divider(),
                        _buildPointsSlider(
                          context,
                          ref,
                          title: 'On-time Completion',
                          description: 'Points awarded for completing a task on time',
                          value: pointsSystem['completionOnTime']!,
                          onChanged: (value) {
                            ref.read(pointsSystemProvider.notifier).state = {
                              ...pointsSystem,
                              'completionOnTime': value,
                            };
                          },
                        ),
                        const Divider(),
                        _buildPointsSlider(
                          context,
                          ref,
                          title: 'Basic Completion',
                          description: 'Base points awarded for any task completion',
                          value: pointsSystem['basicCompletion']!,
                          onChanged: (value) {
                            ref.read(pointsSystemProvider.notifier).state = {
                              ...pointsSystem,
                              'basicCompletion': value,
                            };
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _savePointsSystem(context, ref);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
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
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildPointsSlider(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String description,
    required int value,
    required Function(int) onChanged,
    int max = 10,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    value.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
        ),
        const SizedBox(height: 8),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: max.toDouble(),
          divisions: max,
          label: value.toString(),
          onChanged: (value) => onChanged(value.round()),
        ),
      ],
    );
  }

  void _savePointsSystem(BuildContext context, WidgetRef ref) {
    final pointsSystem = ref.read(pointsSystemProvider);
    
    // In a real implementation, you would update the database here
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Points system updated successfully'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }
} 