-- Check existing RLS policies on the tasks table
SELECT tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'tasks';

-- Drop and recreate policies for the tasks table
DROP POLICY IF EXISTS "Managers can create tasks" ON public.tasks;
DROP POLICY IF EXISTS "Users can view their assigned tasks" ON public.tasks;
DROP POLICY IF EXISTS "Managers and admins can view all tasks" ON public.tasks;
DROP POLICY IF EXISTS "Managers can update tasks" ON public.tasks;
DROP POLICY IF EXISTS "Employees can update their tasks" ON public.tasks;

-- Create simplified policies
CREATE POLICY "Managers can create tasks"
  ON public.tasks FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT role FROM public.users WHERE id = auth.uid()) IN ('manager', 'admin')
  );

CREATE POLICY "Managers can update tasks"
  ON public.tasks FOR UPDATE
  TO authenticated
  USING (
    (SELECT role FROM public.users WHERE id = auth.uid()) IN ('manager', 'admin')
  );

CREATE POLICY "Users can view their assigned tasks"
  ON public.tasks FOR SELECT
  TO authenticated
  USING (
    assigned_to = auth.uid() OR
    (SELECT role FROM public.users WHERE id = auth.uid()) IN ('manager', 'admin')
  );

CREATE POLICY "Employees can update their tasks"
  ON public.tasks FOR UPDATE
  TO authenticated
  USING (
    assigned_to = auth.uid()
  ); 