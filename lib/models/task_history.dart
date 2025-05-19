import 'package:flutter/foundation.dart';

class TaskHistory {
  final String id;
  final String taskId;
  final String status;
  final DateTime timestamp;
  final String changedBy;

  TaskHistory({
    required this.id,
    required this.taskId,
    required this.status,
    required this.timestamp,
    required this.changedBy,
  });

  TaskHistory copyWith({
    String? id,
    String? taskId,
    String? status,
    DateTime? timestamp,
    String? changedBy,
  }) {
    return TaskHistory(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      changedBy: changedBy ?? this.changedBy,
    );
  }

  factory TaskHistory.fromJson(Map<String, dynamic> json) {
    return TaskHistory(
      id: json['id'],
      taskId: json['task_id'],
      status: json['status'],
      timestamp: DateTime.parse(json['timestamp']),
      changedBy: json['changed_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      'changed_by': changedBy,
    };
  }
} 