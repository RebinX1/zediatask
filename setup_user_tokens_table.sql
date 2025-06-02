-- Setup script for user_tokens table
-- This script will create the user_tokens table and migrate any existing tokens

-- Step 1: Create user_tokens table for storing FCM tokens
CREATE TABLE IF NOT EXISTS public.user_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users NOT NULL,
  fcm_token TEXT NOT NULL,
  device_info JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 2: Enable Row Level Security
ALTER TABLE public.user_tokens ENABLE ROW LEVEL SECURITY;

-- Step 3: Drop existing policies first (in case they exist)
DROP POLICY IF EXISTS "Users can insert their own tokens" ON public.user_tokens;
DROP POLICY IF EXISTS "Users can update their own tokens" ON public.user_tokens;
DROP POLICY IF EXISTS "Users can view their own tokens" ON public.user_tokens;
DROP POLICY IF EXISTS "Users can delete their own tokens" ON public.user_tokens;

-- Step 4: Create RLS policies
CREATE POLICY "Users can insert their own tokens"
  ON public.user_tokens FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own tokens"
  ON public.user_tokens FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own tokens"
  ON public.user_tokens FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own tokens"
  ON public.user_tokens FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Step 5: Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS user_tokens_user_id_idx ON public.user_tokens (user_id);
CREATE INDEX IF NOT EXISTS user_tokens_fcm_token_idx ON public.user_tokens (fcm_token);

-- Step 6: Migrate existing tokens from users table (if the notificationtoken column exists)
-- This will copy any existing tokens from the users.notificationtoken column to the new user_tokens table
DO $$
BEGIN
  -- Check if the notificationtoken column exists in the users table
  IF EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'users' 
    AND column_name = 'notificationtoken'
    AND table_schema = 'public'
  ) THEN
    -- Insert existing tokens into user_tokens table
    INSERT INTO public.user_tokens (user_id, fcm_token, device_info, created_at, updated_at)
    SELECT 
      id as user_id,
      notificationtoken as fcm_token,
      jsonb_build_object(
        'migrated_from', 'users_table',
        'platform', 'flutter',
        'migration_date', NOW()
      ) as device_info,
      created_at,
      updated_at
    FROM public.users 
    WHERE notificationtoken IS NOT NULL 
    AND notificationtoken != ''
    ON CONFLICT DO NOTHING; -- Avoid duplicates if script is run multiple times
    
    RAISE NOTICE 'Migration completed: Existing FCM tokens copied from users table to user_tokens table';
  ELSE
    RAISE NOTICE 'No notificationtoken column found in users table - no migration needed';
  END IF;
END $$;

-- Step 7: Create a function to automatically update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_tokens_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 8: Create trigger to automatically update updated_at
DROP TRIGGER IF EXISTS update_user_tokens_updated_at_trigger ON public.user_tokens;
CREATE TRIGGER update_user_tokens_updated_at_trigger
  BEFORE UPDATE ON public.user_tokens
  FOR EACH ROW
  EXECUTE FUNCTION update_user_tokens_updated_at();

-- Step 9: Add a unique constraint to prevent duplicate tokens per user
-- This allows multiple devices per user but prevents the same token being stored twice
CREATE UNIQUE INDEX IF NOT EXISTS user_tokens_user_fcm_unique 
ON public.user_tokens (user_id, fcm_token);

RAISE NOTICE 'user_tokens table setup completed successfully!';
RAISE NOTICE 'All services should now use the user_tokens table for FCM token storage.'; 