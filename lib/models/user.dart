import 'package:flutter/foundation.dart';

enum UserRole {
  admin,
  manager,
  employee,
}

// Extension to add string conversion methods to UserRole
extension UserRoleExtension on UserRole {
  String toStringValue() {
    return toString().split('.').last;
  }
  
  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'employee':
        return UserRole.employee;
      default:
        return UserRole.employee;
    }
  }
}

class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final int? totalPoints;
  final int? tasksCompleted;
  final double? avgCompletionTime;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.totalPoints,
    this.tasksCompleted,
    this.avgCompletionTime,
    required this.createdAt,
    required this.updatedAt,
  });

  User copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    int? totalPoints,
    int? tasksCompleted,
    double? avgCompletionTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      totalPoints: totalPoints ?? this.totalPoints,
      tasksCompleted: tasksCompleted ?? this.tasksCompleted,
      avgCompletionTime: avgCompletionTime ?? this.avgCompletionTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: _parseUserRole(json['role']),
      totalPoints: json['total_points'],
      tasksCompleted: json['tasks_completed'],
      avgCompletionTime: json['avg_completion_time']?.toDouble(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.toString().split('.').last,
      'total_points': totalPoints,
      'tasks_completed': tasksCompleted,
      'avg_completion_time': avgCompletionTime,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static UserRole _parseUserRole(String role) {
    switch (role) {
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'employee':
        return UserRole.employee;
      default:
        return UserRole.employee;
    }
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isManager => role == UserRole.manager || role == UserRole.admin;
  bool get isEmployee => role == UserRole.employee;
} 