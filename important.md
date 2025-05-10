-- Enable RLS for the tasks table if it's not already enabled
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to start fresh
DROP POLICY IF EXISTS "Managers can create tasks" ON public.tasks;
DROP POLICY IF EXISTS "Users can view their assigned tasks" ON public.tasks;
DROP POLICY IF EXISTS "Managers and admins can view all tasks" ON public.tasks;

-- Create policies for task management
-- 1. Allow managers and admins to create tasks
CREATE POLICY "Managers can create tasks"
  ON public.tasks FOR INSERT
  TO authenticated
  USING (
    (SELECT role FROM public.users WHERE id = auth.uid()) IN ('manager', 'admin')
  );

-- 2. Allow managers and admins to update any task
CREATE POLICY "Managers can update tasks"
  ON public.tasks FOR UPDATE
  TO authenticated
  USING (
    (SELECT role FROM public.users WHERE id = auth.uid()) IN ('manager', 'admin')
  );

-- 3. Allow employees to view tasks assigned to them
CREATE POLICY "Users can view their assigned tasks"
  ON public.tasks FOR SELECT
  TO authenticated
  USING (
    assigned_to = auth.uid() OR
    (SELECT role FROM public.users WHERE id = auth.uid()) IN ('manager', 'admin')
  );

-- 4. Allow employees to update tasks assigned to them (to change status)
CREATE POLICY "Employees can update their tasks"
  ON public.tasks FOR UPDATE
  TO authenticated
  USING (
    assigned_to = auth.uid()
  );