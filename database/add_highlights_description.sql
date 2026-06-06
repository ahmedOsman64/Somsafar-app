-- Fix: Add missing columns to travel_highlights table
-- Error: Could not find the 'description' column of 'travel_highlights' in the schema cache (PGRST204)

-- Add description column (was missing from the original schema)
ALTER TABLE public.travel_highlights
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS location    text,
  ADD COLUMN IF NOT EXISTS tag         text,
  ADD COLUMN IF NOT EXISTS image_url   text,
  ADD COLUMN IF NOT EXISTS display_order integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS active      boolean DEFAULT true;

-- Notify PostgREST to reload its schema cache
NOTIFY pgrst, 'reload schema';
