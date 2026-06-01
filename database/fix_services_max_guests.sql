-- Add missing max_guests column to services table
-- Run this in your Supabase SQL Editor

-- 1. Add the column if it doesn't exist
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS max_guests integer;

-- 2. Optional: Migration to sync existing metadata to the new column
-- If you already have services with maxGuests in their metadata, this will copy it to the top level.
UPDATE public.services 
SET max_guests = (metadata->>'maxGuests')::integer 
WHERE max_guests IS NULL AND metadata->>'maxGuests' IS NOT NULL;

-- 3. Verify the column exists
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'services' AND column_name = 'max_guests';
