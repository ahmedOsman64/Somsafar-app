-- SQL Fix for missing user columns
-- Run this in your Supabase SQL Editor

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS nationality text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS date_of_birth timestamp with time zone;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS profile_image text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT now();
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS provider_id text;

-- Optional: Update existing rows to have an updated_at
UPDATE public.users SET updated_at = now() WHERE updated_at IS NULL;
