-- Create user_tokens table for storing FCM tokens
CREATE TABLE IF NOT EXISTS public.user_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users NOT NULL,
  fcm_token TEXT NOT NULL,
  device_info JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.user_tokens ENABLE ROW LEVEL SECURITY;

-- Drop existing policies first
DROP POLICY IF EXISTS "Users can insert their own tokens" ON public.user_tokens;
DROP POLICY IF EXISTS "Users can update their own tokens" ON public.user_tokens;
DROP POLICY IF EXISTS "Users can view their own tokens" ON public.user_tokens;
DROP POLICY IF EXISTS "Users can delete their own tokens" ON public.user_tokens;

-- Create RLS policies
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

-- Create index for faster lookups (skips if already exists)
CREATE INDEX IF NOT EXISTS user_tokens_user_id_idx ON public.user_tokens (user_id);
CREATE INDEX IF NOT EXISTS user_tokens_fcm_token_idx ON public.user_tokens (fcm_token); 