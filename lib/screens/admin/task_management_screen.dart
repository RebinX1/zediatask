import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zediatask/models/models.dart';
import 'package:zediatask/providers/providers.dart';
import 'package:zediatask/services/services.dart';
import 'package:zediatask/utils/app_theme.dart';
import 'package:zediatask/utils/date_formatter.dart';
import 'package:zediatask/widgets/task_card.dart';

// Filter by employee provider
final taskEmployeeFilterProvider = StateProvider<String?>((ref) => null);

// This helps track the active overlay entry for showing messages
OverlayEntry? _taskOverlayEntry;

void _showTaskMessageOverlay(String message, {bool isError = false}) {
  // Remove any existing overlay first
  _hideTaskMessageOverlay();
  
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
                onPressed: _hideTaskMessageOverlay,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  
  // Store the current overlay entry
  _taskOverlayEntry = overlayEntry;
  
  // Add the overlay to the navigator
  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      final state = _taskOverlayState;
      if (state != null) {
        state.insert(overlayEntry);
        
        // Remove after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (_taskOverlayEntry == overlayEntry) {
            _hideTaskMessageOverlay();
          }
        });
      }
    } catch (e) {
      print('Error showing task message overlay: $e');
    }
  });
}

void _hideTaskMessageOverlay() {
  _taskOverlayEntry?.remove();
  _taskOverlayEntry = null;
}

BuildContext? _taskGlobalContext;

OverlayState? get _taskOverlayState {
  if (_taskGlobalContext == null) return null;
  final navigatorState = Navigator.of(_taskGlobalContext!, rootNavigator: true);
  return navigatorState.overlay;
}

class TaskManagementScreen extends ConsumerWidget {
  const TaskManagementScreen({super.key});
  
  // Add a global key for the scaffold messenger
  static final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Store the context for overlay usage
    _taskGlobalContext = context;
    
    final userRoleAsync = ref.watch(userRoleProvider);
    final allTasksAsync = ref.watch(allTasksProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final employeeFilter = ref.watch(taskEmployeeFilterProvider);
    
    // Watch the task update notifier (but don't create circular dependencies)
    ref.watch(taskUpdateNotifierProvider);
    
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Task Management'),
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
                // Add Task Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddTaskDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Task'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ),
                
                // Employee Filter
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: AppTheme.textSecondaryColor),
                      const SizedBox(width: 8),
                      const Text('Filter by Employee:'),
                      const SizedBox(width: 16),
                      Expanded(
                        child: employeesAsync.when(
                          data: (employees) {
                            return DropdownButtonFormField<String?>(
                              value: employeeFilter,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('All Employees'),
                                ),
                                ...employees.map((employee) {
                                  return DropdownMenuItem(
                                    value: employee['id'],
                                    child: Text(employee['name']),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                ref.read(taskEmployeeFilterProvider.notifier).state = value;
                              },
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => const Text('Error loading employees'),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Task list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.refresh(allTasksProvider);
                    },
                    child: allTasksAsync.when(
                      data: (tasks) {
                        // Filter tasks if employee filter is set
                        final filteredTasks = employeeFilter != null
                            ? tasks.where((task) => task.assignedTo == employeeFilter).toList()
                            : tasks;
                            
                        if (filteredTasks.isEmpty) {
                          return const Center(
                            child: Text('No tasks found'),
                          );
                        }
                        
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredTasks.length,
                          itemBuilder: (context, index) {
                            final task = filteredTasks[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildTaskItem(context, ref, task, employeesAsync),
                            );
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

  Widget _buildTaskItem(
    BuildContext context, 
    WidgetRef ref, 
    Task task,
    AsyncValue<List<dynamic>> employeesAsync,
  ) {
    // Get employee name for display
    String assignedToName = 'Unknown';
    
    if (employeesAsync.value != null) {
      final employee = employeesAsync.value!.firstWhere(
        (e) => e['id'] == task.assignedTo,
        orElse: () => {'name': 'Unknown'},
      );
      assignedToName = employee['name'];
    }
    
    return Stack(
      children: [
        TaskCard(task: task, showActions: false),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                color: AppTheme.primaryColor,
                onPressed: () => _showEditTaskDialog(context, ref, task),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                color: AppTheme.errorColor,
                onPressed: () => _showDeleteConfirmation(context, ref, task),
              ),
            ],
          ),
        ),
        // Show assigned employee
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.person,
                  size: 14,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  assignedToName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddTaskDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final dueDateController = TextEditingController();
    DateTime? selectedDueDate;
    TaskPriority selectedPriority = TaskPriority.medium;
    String? selectedEmployee;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create New Task'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Task Title',
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  // Due Date Picker
                  TextField(
                    controller: dueDateController,
                    decoration: const InputDecoration(
                      labelText: 'Due Date (Optional)',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      
                      if (pickedDate != null) {
                        setState(() {
                          selectedDueDate = pickedDate;
                          dueDateController.text = DateFormatter.formatDate(pickedDate);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Priority Selector
                  DropdownButtonFormField<TaskPriority>(
                    value: selectedPriority,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      prefixIcon: Icon(Icons.flag),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: TaskPriority.low,
                        child: Text('Low'),
                      ),
                      DropdownMenuItem(
                        value: TaskPriority.medium,
                        child: Text('Medium'),
                      ),
                      DropdownMenuItem(
                        value: TaskPriority.high,
                        child: Text('High'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedPriority = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Employee Selector
                  const Text('Assign to:'),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final employeesAsync = ref.watch(employeesProvider);
                      
                      return employeesAsync.when(
                        data: (employees) {
                          if (employees.isEmpty) {
                            return const Text('No employees available');
                          }
                          
                          return DropdownButtonFormField<String>(
                            value: selectedEmployee,
                            decoration: const InputDecoration(
                              labelText: 'Employee',
                              prefixIcon: Icon(Icons.person),
                            ),
                            items: employees.map<DropdownMenuItem<String>>((employee) {
                              return DropdownMenuItem<String>(
                                value: employee['id'],
                                child: Text(employee['name']),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  selectedEmployee = value;
                                });
                              }
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Error loading employees'),
                      );
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
                  _createTask(
                    context, 
                    ref, 
                    titleController.text.trim(), 
                    descriptionController.text.trim(), 
                    selectedEmployee ?? '',
                    selectedPriority,
                    selectedDueDate,
                  );
                },
                child: const Text('Create Task'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditTaskDialog(BuildContext context, WidgetRef ref, Task task) {
    final titleController = TextEditingController(text: task.title);
    final descriptionController = TextEditingController(text: task.description);
    final dueDateController = TextEditingController(
      text: task.dueDate != null ? DateFormatter.formatDate(task.dueDate!) : '',
    );
    
    DateTime? selectedDueDate = task.dueDate;
    TaskPriority selectedPriority = task.priority;
    String selectedEmployee = task.assignedTo;
    TaskStatus selectedStatus = task.status;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Task'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Task Title',
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  // Due Date Picker
                  TextField(
                    controller: dueDateController,
                    decoration: const InputDecoration(
                      labelText: 'Due Date (Optional)',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDueDate ?? DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      
                      if (pickedDate != null) {
                        setState(() {
                          selectedDueDate = pickedDate;
                          dueDateController.text = DateFormatter.formatDate(pickedDate);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Status Selector
                  DropdownButtonFormField<TaskStatus>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icon(Icons.sync),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: TaskStatus.pending,
                        child: Text('Pending'),
                      ),
                      DropdownMenuItem(
                        value: TaskStatus.accepted,
                        child: Text('Accepted'),
                      ),
                      DropdownMenuItem(
                        value: TaskStatus.completed,
                        child: Text('Completed'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedStatus = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Priority Selector
                  DropdownButtonFormField<TaskPriority>(
                    value: selectedPriority,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      prefixIcon: Icon(Icons.flag),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: TaskPriority.low,
                        child: Text('Low'),
                      ),
                      DropdownMenuItem(
                        value: TaskPriority.medium,
                        child: Text('Medium'),
                      ),
                      DropdownMenuItem(
                        value: TaskPriority.high,
                        child: Text('High'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedPriority = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Employee Selector
                  const Text('Assign to:'),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final employeesAsync = ref.watch(employeesProvider);
                      
                      return employeesAsync.when(
                        data: (employees) {
                          if (employees.isEmpty) {
                            return const Text('No employees available');
                          }
                          
                          return DropdownButtonFormField<String>(
                            value: selectedEmployee,
                            decoration: const InputDecoration(
                              labelText: 'Employee',
                              prefixIcon: Icon(Icons.person),
                            ),
                            items: employees.map<DropdownMenuItem<String>>((employee) {
                              return DropdownMenuItem<String>(
                                value: employee['id'],
                                child: Text(employee['name']),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  selectedEmployee = value;
                                });
                              }
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Error loading employees'),
                      );
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
                  _updateTask(
                    context, 
                    ref, 
                    task.id,
                    titleController.text.trim(), 
                    descriptionController.text.trim(), 
                    selectedEmployee,
                    selectedPriority,
                    selectedStatus,
                    selectedDueDate,
                  );
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteTask(context, ref, task.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _createTask(
    BuildContext context,
    WidgetRef ref,
    String title,
    String description,
    String assignedTo,
    TaskPriority priority,
    DateTime? dueDate,
  ) async {
    if (title.isEmpty || description.isEmpty || assignedTo.isEmpty) {
      _showTaskMessageOverlay('Please fill in all required fields', isError: true);
      return;
    }
    
    try {
      Navigator.of(context).pop(); // Close the dialog
      
      // Show loading indicator
      _showTaskMessageOverlay('Creating task...');
      
      final supabaseService = ref.read(supabaseServiceProvider);
      await supabaseService.createTask(
        title: title,
        description: description,
        assignedTo: assignedTo,
        priority: priority,
        dueDate: dueDate,
      );
      
      // Hide any existing message
      _hideTaskMessageOverlay();
      
      // Show success message
      _showTaskMessageOverlay('Task created successfully');
      
      // Notify other components about the task update
      notifyTaskUpdate(ref);
    } catch (e) {
      _hideTaskMessageOverlay();
      _showTaskMessageOverlay('Error creating task: ${e.toString()}', isError: true);
    }
  }

  Future<void> _updateTask(
    BuildContext context,
    WidgetRef ref,
    String taskId,
    String title,
    String description,
    String assignedTo,
    TaskPriority priority,
    TaskStatus status,
    DateTime? dueDate,
  ) async {
    if (title.isEmpty || description.isEmpty || assignedTo.isEmpty) {
      _showTaskMessageOverlay('Please fill in all required fields', isError: true);
      return;
    }
    
    try {
      Navigator.of(context).pop(); // Close the dialog
      
      // Show loading indicator
      _showTaskMessageOverlay('Updating task...');
      
      final supabaseService = ref.read(supabaseServiceProvider);
      final client = supabaseService.client;
      
      // Update task in database
      final updateData = {
        'title': title,
        'description': description,
        'assigned_to': assignedTo,
        'priority': priority.toString().split('.').last,
        'status': status.toString().split('.').last,
      };
      
      if (dueDate != null) {
        updateData['due_date'] = dueDate.toIso8601String();
      }
      
      await client.from('tasks').update(updateData).eq('id', taskId);
      
      // Hide any existing message
      _hideTaskMessageOverlay();
      
      // Show success message
      _showTaskMessageOverlay('Task updated successfully');
      
      // Notify other components about the task update
      notifyTaskUpdate(ref);
    } catch (e) {
      _hideTaskMessageOverlay();
      _showTaskMessageOverlay('Error updating task: ${e.toString()}', isError: true);
    }
  }

  Future<void> _deleteTask(
    BuildContext context,
    WidgetRef ref,
    String taskId,
  ) async {
    try {
      // Show loading indicator
      _showTaskMessageOverlay('Deleting task...');
      
      final supabaseService = ref.read(supabaseServiceProvider);
      final client = supabaseService.client;
      
      // In a real application, you would implement proper cascading deletion
      // of related records (comments, attachments, etc.)
      await client.from('tasks').delete().eq('id', taskId);
      
      // Hide any existing message
      _hideTaskMessageOverlay();
      
      // Show success message
      _showTaskMessageOverlay('Task deleted successfully');
      
      // Notify other components about the task update
      notifyTaskUpdate(ref);
    } catch (e) {
      _hideTaskMessageOverlay();
      _showTaskMessageOverlay('Error deleting task: ${e.toString()}', isError: true);
    }
  }
} 