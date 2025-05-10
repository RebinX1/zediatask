📝 Task Management App – Project Proposal
📌 Project Overview
The Task Management App is a mobile and web-based platform designed for internal company use, enabling managers to assign tasks to employees, track task progress, and measure performance. Built using Flutter (cross-platform frontend) and Supabase (backend/database/auth), the app promotes accountability, productivity, and team communication through task tracking, performance metrics, and a gamified points/leaderboard system.

👥 User Roles
1. Admin / Manager
Assign and manage tasks

Leave comments and instructions

Track employee performance

Add attachments and deadlines

2. Employee
View and accept assigned tasks

Complete tasks and mark them done

View comments and instructions

Earn points based on speed and quantity

Provide feedback after completing tasks

🧩 Core Features
✅ Task Management Workflow
Managers assign tasks to employees.

Employees accept and complete tasks.

The system logs timestamps:

Time assigned

Time accepted

Time completed

🧠 Gamification and Performance Tracking
Employees earn points for:

Fast task acceptance

Fast and timely completion

A leaderboard ranks employees based on:

Total points

Number of completed tasks

Average completion time

💬 Comment System
Managers can leave comments on tasks before or after acceptance.

Employees view these comments in task details.

Future enhancement: allow replies for two-way communication.

🚀 Advanced Features
1. Task Deadlines & Reminders
Each task includes a due_date.

System sends reminders (via push/email) before deadlines.

Overdue tasks are highlighted in the UI.

2. Task Priorities & Tags
Tasks can have a priority: high, medium, low.

Tags (e.g., “maintenance”, “delivery”) allow filtering and categorization.

3. Push Notifications
Employees receive:

New task alerts

Comment updates

Deadline reminders

Uses Firebase Cloud Messaging (FCM) integrated with Flutter.

4. Attachments
Managers can upload files (images, PDFs, documents) to tasks.

Employees can view/download attachments for instructions or documentation.

5. Task Status History
Every change in task status (e.g., assigned → accepted → completed) is recorded with a timestamp.

Useful for audits, reviews, and identifying delays.

6. Employee Feedback / Notes
After completing a task, employees can leave a short comment or note.

Helps gather insights from the ground level.

🗃️ Database Schema (Simplified)
users
id, name, role (admin, manager, employee)

tasks
id, title, description, assigned_to, created_by

created_at, due_date, accepted_at, completed_at

status (pending, accepted, completed)

priority, tags, points_awarded

comments
id, task_id, author_id, content, created_at, visible_to_employee

attachments
id, task_id, file_url, uploaded_by, created_at

task_history
id, task_id, status, timestamp, changed_by

feedback
id, task_id, user_id, content, created_at

leaderboard (view or aggregation)
user_id, total_points, tasks_completed, avg_completion_time

🧱 Tech Stack
Frontend: Flutter (Android, iOS, Web)

Backend: Supabase (PostgreSQL + Realtime + Auth)

Notifications: Firebase Cloud Messaging (FCM)

File Uploads: Supabase Storage

Authentication: Supabase Auth with role metadata

🔐 Security and Permissions
Role-based access:

Admins/Managers can create, assign, comment, and upload.

Employees can only see their own tasks and submit completion/feedback.

Supabase Row-Level Security (RLS) policies ensure strict access control.


