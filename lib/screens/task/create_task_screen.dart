import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:zediatask/models/models.dart';
import 'package:zediatask/providers/providers.dart';
import 'package:zediatask/providers/notification_provider.dart';
import 'package:zediatask/utils/app_theme.dart';
import 'package:path/path.dart' as path;

class CreateTaskScreen extends ConsumerStatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _dueDate;
  String? _selectedEmployeeId;
  TaskPriority _selectedPriority = TaskPriority.medium;
  final List<String> _tags = [];
  final _tagController = TextEditingController();
  bool _isLoading = false;
  bool _isGroupTask = false;
  final List<String> _selectedEmployeeIds = [];
  final List<File> _files = [];
  final List<String> _fileNames = [];
  final List<bool> _uploading = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _createTask() async {
    // Validate form
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final supabaseService = ref.read(supabaseServiceProvider);
        
        // Check if user is authenticated
        final userId = supabaseService.client.auth.currentUser?.id;
        
        if (userId == null) {
          throw Exception('You are not authenticated. Please log in again.');
        }
        
        // Verify authentication before creating task
        final isAuthValid = await supabaseService.verifyAndRefreshAuth();
        
        if (!isAuthValid) {
          throw Exception('Authentication failed. Please log in again.');
        }
        
        // Attempt to create the task
        Task? createdTask;
        bool usedFallback = false;
        
        // Determine whether this is a group task or regular task
        if (_isGroupTask && _selectedEmployeeIds.isNotEmpty) {
          // Create a group task
          createdTask = await supabaseService.createGroupTask(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            employeeIds: _selectedEmployeeIds,
            priority: _selectedPriority,
            dueDate: _dueDate,
            tags: _tags,
          );
        } else {
          // Create a regular task
          createdTask = await supabaseService.createTask(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            assignedTo: _selectedEmployeeId ?? '',
            priority: _selectedPriority,
            dueDate: _dueDate,
            tags: _tags,
          );
        }
        
        // Add attachments if they exist
        if (_files.isNotEmpty && createdTask != null) {
          for (int i = 0; i < _files.length; i++) {
            if (_uploading[i]) {
              await supabaseService.uploadTaskAttachment(
                taskId: createdTask.id,
                filePath: _files[i].path,
                fileName: _fileNames[i] ?? path.basename(_files[i].path),
              );
            }
          }
        }
        
        if (createdTask != null) {
          // Update the tasks list
          ref.refresh(userTasksProvider); 
          ref.read(taskUpdateNotifierProvider.notifier).state = DateTime.now();
          
          // Send push notifications to assigned users
          try {
            final pushNotificationService = ref.read(pushNotificationServiceProvider);
            List<String> targetUserIds = [];
            
            if (_isGroupTask && _selectedEmployeeIds.isNotEmpty) {
              // For group tasks, send to all selected employees
              targetUserIds = _selectedEmployeeIds;
            } else if (_selectedEmployeeId != null && _selectedEmployeeId!.isNotEmpty) {
              // For individual tasks, send to the assigned employee
              targetUserIds = [_selectedEmployeeId!];
            }
            
            if (targetUserIds.isNotEmpty) {
              debugPrint('Sending notifications to ${targetUserIds.length} users for task: ${createdTask.title}');
              
              final results = await pushNotificationService.sendTaskAssignmentNotifications(
                userIds: targetUserIds,
                taskTitle: createdTask.title,
                taskId: createdTask.id,
                isGroupTask: _isGroupTask,
              );
              
              // Log results
              int successCount = results.values.where((success) => success).length;
              debugPrint('✅ Notifications sent successfully: $successCount/${targetUserIds.length}');
              
              if (mounted && successCount > 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Task created and notifications sent to $successCount user(s)'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } else {
              debugPrint('No users selected for notifications');
            }
          } catch (e) {
            debugPrint('Error sending notifications: $e');
            // Don't show error to user as task was created successfully
          }
        }

        if (mounted) {
          final result = createdTask ?? Task(
            id: 'error_${DateTime.now().millisecondsSinceEpoch}',
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            assignedTo: _selectedEmployeeId ?? '',
            createdBy: userId,
            createdAt: DateTime.now(),
            status: TaskStatus.pending,
            priority: _selectedPriority,
            tags: _tags,
          );
          
          Navigator.of(context).pop(result);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null && picked != _dueDate) {
      // Show time picker
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          _dueDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      } else {
        setState(() {
          _dueDate = picked;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Task'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title field
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description field
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Due date field
            InkWell(
              onTap: () => _selectDueDate(context),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Due Date',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _dueDate == null
                      ? 'Select due date'
                      : DateFormat('MMM d, yyyy - h:mm a').format(_dueDate!),
                  style: _dueDate == null
                      ? TextStyle(color: AppTheme.textSecondaryColor)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Priority selector
            DropdownButtonFormField<TaskPriority>(
              value: _selectedPriority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                prefixIcon: Icon(Icons.flag),
              ),
              items: TaskPriority.values.map((priority) {
                final String label;
                final Color color;
                
                switch (priority) {
                  case TaskPriority.low:
                    label = 'Low';
                    color = AppTheme.lowPriorityColor;
                    break;
                  case TaskPriority.medium:
                    label = 'Medium';
                    color = AppTheme.mediumPriorityColor;
                    break;
                  case TaskPriority.high:
                    label = 'High';
                    color = AppTheme.highPriorityColor;
                    break;
                }
                
                return DropdownMenuItem<TaskPriority>(
                  value: priority,
                  child: Row(
                    children: [
                      Icon(
                        priority == TaskPriority.low
                            ? Icons.arrow_downward
                            : priority == TaskPriority.medium
                                ? Icons.remove
                                : Icons.arrow_upward,
                        color: color,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPriority = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Task assignment type toggle
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Single Employee'),
                    value: false,
                    groupValue: _isGroupTask,
                    onChanged: (value) {
                      setState(() {
                        _isGroupTask = value!;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Group Task'),
                    value: true,
                    groupValue: _isGroupTask,
                    onChanged: (value) {
                      setState(() {
                        _isGroupTask = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Employee selector
            employeesAsync.when(
              data: (employees) {
                if (employees.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('No employees available', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('Please create employee users in Supabase'),
                          TextButton(
                            onPressed: () {
                              // Refresh the employees list
                              ref.refresh(employeesProvider);
                            },
                            child: const Text('Refresh'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                if (_isGroupTask) {
                  // Multi-select for group task
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Employees:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...employees.map((employee) {
                        return CheckboxListTile(
                          title: Text('${employee['name'] ?? 'Unknown'} (${employee['email'] ?? 'No email'})'),
                          value: _selectedEmployeeIds.contains(employee['id']),
                          onChanged: (bool? selected) {
                            setState(() {
                              if (selected == true) {
                                if (!_selectedEmployeeIds.contains(employee['id'])) {
                                  _selectedEmployeeIds.add(employee['id']);
                                }
                              } else {
                                _selectedEmployeeIds.remove(employee['id']);
                              }
                            });
                          },
                        );
                      }).toList(),
                      if (_selectedEmployeeIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Selected: ${_selectedEmployeeIds.length} employees',
                            style: TextStyle(color: AppTheme.primaryColor),
                          ),
                        ),
                    ],
                  );
                } else {
                  // Single select for regular task
                  return DropdownButtonFormField<String>(
                    value: _selectedEmployeeId,
                    decoration: const InputDecoration(
                      labelText: 'Assign To',
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: employees.map((employee) {
                      return DropdownMenuItem<String>(
                        value: employee['id'],
                        child: Text('${employee['name'] ?? 'Unknown'} (${employee['email'] ?? 'No email'})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedEmployeeId = value;
                      });
                    },
                  );
                }
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text('Error: $error', style: TextStyle(color: AppTheme.errorColor)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          // Refresh the employees list
                          ref.refresh(employeesProvider);
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tags section
            Text(
              'Tags',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      labelText: 'Add Tag',
                      prefixIcon: Icon(Icons.tag),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add),
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Tags list
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) {
                return Chip(
                  label: Text(tag),
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: AppTheme.primaryColor,
                  ),
                  deleteIcon: const Icon(
                    Icons.close,
                    size: 16,
                  ),
                  onDeleted: () => _removeTag(tag),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Create button
            ElevatedButton(
              onPressed: _isLoading ? null : _createTask,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create Task'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailedResults(BuildContext context, Map<String, dynamic> results) {
    // Method removed for release version
  }
} 